using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Responses;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Payments;

internal sealed record SettledCharge(int Id, decimal Amount, string Currency);

internal sealed record OwedAmount(decimal Amount, string Reason);

internal sealed record RefundRow(
    int Id,
    int PaymentId,
    RefundStatus Status,
    decimal Amount,
    string Currency,
    string Reason,
    DateTime CreatedAt,
    DateTime? ProcessedAt,
    string? FailureReason);

internal sealed class RefundService(
    GostioDbContext db,
    ReservationAccess reservations,
    StripeSettings stripe) : IRefundService, ICancellationRefunds
{
    private const string ExpiredHoldReason =
        "The charge settled after the reservation hold had run out.";

    // Answers before a cancellation as well as after one, which is the point: a
    // guest is told what calling it off costs while calling it off is still a
    // choice. Against a booking nothing was charged for, it prices the policy on
    // the total instead and says so through `IsPaid`.
    //
    // It is a function of four things, and after a cancellation all four have
    // stopped moving: when the booking was made, when it begins, what was
    // charged, and the instant the policy is read against. That last one is the
    // clock only while the booking is live; once it has ended it is the moment
    // it ended. Without that the same guest could be quoted everything back on
    // Monday and half on Friday against a refund already promised in full.
    public async Task<RefundQuoteResponse> QuoteAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        var booking = await reservations.RequireReachableAsync(reservationId, cancellationToken);
        var charge = await SettledChargeAsync(reservationId, cancellationToken);
        var charged = charge?.Amount ?? booking.TotalPrice;
        var asOf = await AsOfAsync(reservationId, booking.StatusId, cancellationToken);
        var entitlement = CancellationPolicy.For(booking.CreatedAt, booking.StartsAt, asOf);

        return new RefundQuoteResponse
        {
            ReservationId = reservationId,
            IsPaid = charge is not null,
            Charged = charged,
            Currency = charge?.Currency ?? stripe.Currency,
            Percentage = entitlement.Percentage,
            Amount = CancellationPolicy.AmountOf(charged, entitlement.Percentage),
            Reason = entitlement.Reason,
            GraceEndsAt = CancellationPolicy.GraceEndsAt(booking.CreatedAt, booking.StartsAt),
            AsOf = asOf,
        };
    }

    private async Task<DateTime> AsOfAsync(
        int reservationId,
        int statusId,
        CancellationToken cancellationToken)
    {
        if (ReservationStateMachine.RequireKnown(statusId) != ReservationStatusCode.Cancelled)
        {
            return DateTime.UtcNow;
        }

        return await db.ReservationStatusHistory
            .AsNoTracking()
            .Where(history => history.ReservationId == reservationId
                && history.NewStatusId == (int)ReservationStatusCode.Cancelled)
            .MaxAsync(history => (DateTime?)history.ChangedAt, cancellationToken)
            ?? DateTime.UtcNow;
    }

    private Task<OwedAmount?> OwedRefundAsync(int paymentId, CancellationToken cancellationToken) =>
        db.Refunds
            .AsNoTracking()
            .Where(refund => refund.PaymentId == paymentId
                && (refund.Status == RefundStatus.Pending
                    || refund.Status == RefundStatus.Succeeded))
            .Select(refund => new OwedAmount(refund.Amount, refund.Reason))
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<RefundResponse> GetAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        await reservations.RequireReachableAsync(reservationId, cancellationToken);

        var refund = await db.Refunds
            .AsNoTracking()
            .Where(row => row.Payment.ReservationId == reservationId)
            .OrderByDescending(row => row.Id)
            .Select(row => new RefundRow(
                row.Id,
                row.PaymentId,
                row.Status,
                row.Amount,
                row.Payment.Currency,
                row.Reason,
                row.CreatedAt,
                row.ProcessedAt,
                row.FailureReason))
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException($"Reservation {reservationId} is owed nothing back.");

        return new RefundResponse
        {
            Id = refund.Id,
            ReservationId = reservationId,
            PaymentId = refund.PaymentId,
            Status = refund.Status.ToString(),
            Amount = refund.Amount,
            Currency = refund.Currency,
            Reason = refund.Reason,
            CreatedAt = refund.CreatedAt,
            ProcessedAt = refund.ProcessedAt,
            FailureReason = refund.FailureReason,
        };
    }

    // Written inside the transaction that cancels, so a booking can never end
    // holding money without the row that says how much of it goes back. What
    // sends it is not this: the row is the promise, and it stands whether or not
    // the processor can be reached in the same breath. A guest owed nothing gets
    // no row at all, because a refund of zero is one no constraint allows and
    // why they are owed nothing is the quote's answer rather than a row's.
    public async Task RecordAsync(CancelledBooking booking, CancellationToken cancellationToken)
    {
        var charge = await SettledChargeAsync(booking.ReservationId, cancellationToken);

        if (charge is null)
        {
            return;
        }

        var entitlement = CancellationPolicy.For(
            booking.CreatedAt, booking.StartsAt, booking.CancelledAt);

        var amount = CancellationPolicy.AmountOf(charge.Amount, entitlement.Percentage);

        await RecordAsync(
            charge, amount, entitlement.Reason, booking.CancelledAt, cancellationToken);
    }

    public async Task RecordFullAsync(
        int reservationId,
        DateTime owedAt,
        CancellationToken cancellationToken)
    {
        var charge = await SettledChargeAsync(reservationId, cancellationToken);

        if (charge is null)
        {
            return;
        }

        await RecordAsync(
            charge, charge.Amount, ExpiredHoldReason, owedAt, cancellationToken);
    }

    private async Task RecordAsync(
        SettledCharge charge,
        decimal amount,
        string reason,
        DateTime createdAt,
        CancellationToken cancellationToken)
    {
        if (amount <= 0 || await OwedRefundAsync(charge.Id, cancellationToken) is not null)
        {
            return;
        }

        db.Refunds.Add(new Refund
        {
            PaymentId = charge.Id,
            Status = RefundStatus.Pending,
            Amount = amount,
            Reason = reason,
            CreatedAt = createdAt,
        });

        await db.SaveChangesAsync(cancellationToken);
    }

    // A refund is computed from what was actually taken, never from a price
    // recalculated afterwards, so only a settled charge answers here.
    private Task<SettledCharge?> SettledChargeAsync(
        int reservationId,
        CancellationToken cancellationToken) =>
        db.Payments
            .AsNoTracking()
            .Where(payment => payment.ReservationId == reservationId
                && payment.Status == PaymentStatus.Succeeded)
            .Select(payment => new SettledCharge(payment.Id, payment.Amount, payment.Currency))
            .FirstOrDefaultAsync(cancellationToken);
}
