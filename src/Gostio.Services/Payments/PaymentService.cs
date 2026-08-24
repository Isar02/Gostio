using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Payments;

internal sealed record PaymentRow(
    int Id,
    int ReservationId,
    PaymentStatus Status,
    decimal Amount,
    string Currency,
    string? StripePaymentIntentId,
    DateTime CreatedAt,
    DateTime? ProcessedAt,
    string? FailureReason);

internal sealed class PaymentService(
    GostioDbContext db,
    ICurrentUser currentUser,
    ReservationAccess reservations,
    IPaymentGateway gateway,
    StripeSettings stripe) : IPaymentService
{
    public async Task<PaymentResponse> StartAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        if (!stripe.CanTakeAPayment)
        {
            throw new InvalidOperationException(
                "Taking a payment needs STRIPE_SECRET_KEY and STRIPE_PUBLISHABLE_KEY in the "
                    + ".env file.");
        }

        var payment = await OpenAsync(reservationId, cancellationToken);
        var intent = await IntentOfAsync(payment, cancellationToken);

        RequireTheIntentIsStillOpen(intent);

        await RecordTheIntentAsync(payment, intent.Id, cancellationToken);

        return Describe(payment, intent.ClientSecret, stripe.PublishableKey);
    }

    public async Task<PaymentResponse> GetAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        await reservations.RequireReachableAsync(reservationId, cancellationToken);

        var payment = await Of(reservationId)
            .OrderByDescending(row => row.Id)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException(
                $"Reservation {reservationId} has never been paid for.");

        return Describe(payment, clientSecret: null, publishableKey: null);
    }

    // The row a charge hangs off, and the only transaction this needs. The gate,
    // the state, the floor on the amount and the insert all run under the lock,
    // so two taps on one booking queue rather than race the index that forbids
    // the second payment, and no row is ever written for an amount the processor
    // will refuse. The call to the processor is deliberately left outside it.
    private async Task<PaymentRow> OpenAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        var guestId = currentUser.RequireUserId();

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await ReservationLock.TakeAsync(db, reservationId, cancellationToken);

        var now = DateTime.UtcNow;
        var booking = await reservations.RequireReachableAsync(reservationId, cancellationToken);

        if (booking.GuestId != guestId)
        {
            throw new ForbiddenException("Only the guest who booked a reservation pays for it.");
        }

        RequireThePlaceIsStillHeld(booking, now);
        RequireTheAmountCanBeCharged(booking.TotalPrice, stripe.Currency);

        var existing = await Of(reservationId)
            .Where(row => row.Status == PaymentStatus.Pending
                || row.Status == PaymentStatus.Succeeded)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken);

        if (existing is { Status: PaymentStatus.Succeeded })
        {
            throw new BusinessException("This reservation has already been paid for.");
        }

        if (existing is not null)
        {
            await transaction.CommitAsync(cancellationToken);

            return existing;
        }

        var payment = new Payment
        {
            ReservationId = reservationId,
            Status = PaymentStatus.Pending,
            Amount = booking.TotalPrice,
            Currency = stripe.Currency,
            CreatedAt = now,
        };

        db.Payments.Add(payment);

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return new PaymentRow(
            payment.Id,
            reservationId,
            payment.Status,
            payment.Amount,
            payment.Currency,
            payment.StripePaymentIntentId,
            payment.CreatedAt,
            payment.ProcessedAt,
            payment.FailureReason);
    }

    // A row that reached the processor names its charge and is asked about that
    // one again; a row that never did asks for a new one. Two callers that both
    // arrive here carry the same payment id, and the id is the idempotency key,
    // so the processor hands them one charge rather than two. What comes back is
    // then written only where there is nothing, because a charge already
    // recorded has to keep the id it was recorded under: pointing the row at a
    // second charge orphans the first.
    private Task<GatewayIntent> IntentOfAsync(
        PaymentRow payment,
        CancellationToken cancellationToken) =>
        payment.StripePaymentIntentId is string intentId
            ? gateway.ReadIntentAsync(intentId, cancellationToken)
            : gateway.CreateIntentAsync(
                new GatewayIntentRequest(
                    payment.Id, payment.ReservationId, payment.Amount, payment.Currency),
                cancellationToken);

    private Task RecordTheIntentAsync(
        PaymentRow payment,
        string intentId,
        CancellationToken cancellationToken) =>
        db.Payments
            .Where(row => row.Id == payment.Id && row.StripePaymentIntentId == null)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(row => row.StripePaymentIntentId, intentId),
                cancellationToken);

    private IQueryable<Payment> Of(int reservationId) =>
        db.Payments.AsNoTracking().Where(payment => payment.ReservationId == reservationId);

    private static Expression<Func<Payment, PaymentRow>> Projection =>
        payment => new PaymentRow(
            payment.Id,
            payment.ReservationId,
            payment.Status,
            payment.Amount,
            payment.Currency,
            payment.StripePaymentIntentId,
            payment.CreatedAt,
            payment.ProcessedAt,
            payment.FailureReason);

    private static void RequireThePlaceIsStillHeld(ReservationView booking, DateTime now)
    {
        var status = ReservationStateMachine.RequireKnown(booking.StatusId);

        if (status is ReservationStatusCode.Cancelled or ReservationStatusCode.Completed)
        {
            throw new BusinessException($"A {status} reservation is not paid for.");
        }

        if (status == ReservationStatusCode.Pending && booking.ExpiresAt <= now)
        {
            throw new BusinessException("The hold on this booking has run out. Book it again.");
        }
    }

    private static void RequireTheAmountCanBeCharged(decimal amount, string currency)
    {
        var smallest = Currencies.SmallestChargeIn(currency);
        var largest = Currencies.LargestChargeIn(currency);

        if (amount < smallest)
        {
            throw new BusinessException(
                $"A card payment has to be at least {smallest:0.00} {currency.ToUpperInvariant()}, "
                    + $"and this booking comes to {amount:0.00}.");
        }

        if (amount > largest)
        {
            throw new BusinessException(
                $"A card payment cannot exceed {largest:0.00} {currency.ToUpperInvariant()}, "
                    + $"and this booking comes to {amount:0.00}.");
        }
    }

    // A charge the processor has already settled is not one a card sheet opens
    // on. Recording it belongs to the webhook and to nothing here, so this says
    // what happened and leaves the row exactly where it stands.
    private static void RequireTheIntentIsStillOpen(GatewayIntent intent)
    {
        if (intent.State == GatewayIntentState.Open)
        {
            return;
        }

        throw new BusinessException(intent.State == GatewayIntentState.Succeeded
            ? "This payment has gone through and is being recorded. Read it again in a moment."
            : "This payment attempt was cancelled. Start another once it has been recorded.");
    }

    private static PaymentResponse Describe(
        PaymentRow payment,
        string? clientSecret,
        string? publishableKey) =>
        new()
        {
            Id = payment.Id,
            ReservationId = payment.ReservationId,
            Status = payment.Status.ToString(),
            Amount = payment.Amount,
            Currency = payment.Currency,
            ClientSecret = clientSecret,
            PublishableKey = publishableKey,
            CreatedAt = payment.CreatedAt,
            ProcessedAt = payment.ProcessedAt,
            FailureReason = payment.FailureReason,
        };
}
