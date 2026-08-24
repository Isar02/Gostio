using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Validation;
using Gostio.Services.Database;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Gostio.Services.Payments;

// The one writer that ends a payment. Everything here is idempotent by the same
// device the sweep uses: each update names the status it expects to find, so a
// redelivered event matches no row and writes nothing after it.
internal sealed class PaymentSettlement(
    GostioDbContext db,
    IReservationTransitionService transitions,
    ICancellationRefunds refunds,
    ILogger<PaymentSettlement> logger) : IPaymentSettlement
{
    public async Task SettleAsync(
        PaymentOutcomeReport report,
        CancellationToken cancellationToken)
    {
        var charge = await db.Payments
            .AsNoTracking()
            .Where(payment => payment.StripePaymentIntentId == report.IntentId)
            .Select(payment => new { payment.Id, payment.ReservationId, payment.Status })
            .FirstOrDefaultAsync(cancellationToken);

        if (charge is null)
        {
            logger.LogWarning(
                "The processor reported {Outcome} for the charge {IntentId}, which no payment "
                    + "names. Nothing was changed.",
                report.Outcome,
                report.IntentId);

            return;
        }

        if (report.Outcome == PaymentOutcome.Failed)
        {
            await RecordTheDeclineAsync(charge.Id, report.FailureReason, cancellationToken);

            return;
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await ReservationLock.TakeAsync(db, charge.ReservationId, cancellationToken);

        var settled = await CloseAsync(charge.Id, report.Outcome, cancellationToken);

        if (settled && report.Outcome == PaymentOutcome.Succeeded)
        {
            await ConfirmTheBookingAsync(charge.ReservationId, charge.Id, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    // A decline leaves the intent reusable, so the row stays pending with its
    // charge and only the processor's words are kept. Writing anything else
    // would end a payment the guest can still complete on the same card sheet.
    private Task RecordTheDeclineAsync(
        int paymentId,
        string? reason,
        CancellationToken cancellationToken) =>
        db.Payments
            .Where(payment => payment.Id == paymentId
                && payment.Status == PaymentStatus.Pending)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(
                    payment => payment.FailureReason, Reasons.Fit(reason)),
                cancellationToken);

    private async Task<bool> CloseAsync(
        int paymentId,
        PaymentOutcome outcome,
        CancellationToken cancellationToken)
    {
        var status = outcome == PaymentOutcome.Succeeded
            ? PaymentStatus.Succeeded
            : PaymentStatus.Cancelled;

        var processedAt = DateTime.UtcNow;

        var affectedRows = await db.Payments
            .Where(payment => payment.Id == paymentId
                && payment.Status == PaymentStatus.Pending)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(payment => payment.Status, status)
                    .SetProperty(payment => payment.ProcessedAt, (DateTime?)processedAt),
                cancellationToken);

        if (affectedRows == 0)
        {
            logger.LogInformation(
                "The payment {PaymentId} was already settled when {Outcome} arrived, so nothing "
                    + "was changed.",
                paymentId,
                outcome);
        }

        return affectedRows > 0;
    }

    // Money arriving is what confirms a booking, and Stripe is not a person, so
    // the trail names nobody. A booking that was not pending is left where it
    // stands: a host may have confirmed it first, or it may have been cancelled
    // while the charge was in flight. That second case ends holding money with
    // nothing to hold it against, so the same row a cancellation writes is
    // written here — priced against the moment the booking ended and never
    // against now, because an event the processor delivered late must not cost a
    // guest a threshold they were inside of when they called it off.
    private async Task ConfirmTheBookingAsync(
        int reservationId,
        int paymentId,
        CancellationToken cancellationToken)
    {
        try
        {
            await transitions.MoveAsync(
                reservationId,
                (int)ReservationStatusCode.Pending,
                ReservationStatusCode.Confirmed,
                changedByUserId: null,
                reason: null,
                cancellationToken);
        }
        catch (BusinessException)
        {
            logger.LogWarning(
                "The payment {PaymentId} settled against the reservation {ReservationId}, which "
                    + "was no longer pending. The charge stands and the booking was left as it is.",
                paymentId,
                reservationId);

            await OweTheChargeBackAsync(reservationId, cancellationToken);
        }
    }

    private async Task OweTheChargeBackAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        var ended = await db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId
                && reservation.ReservationStatusId == (int)ReservationStatusCode.Cancelled)
            .Select(reservation => new
            {
                reservation.CreatedAt,
                reservation.CheckInDate,
                SlotStartTime = reservation.ExperienceSlot != null
                    ? (DateTime?)reservation.ExperienceSlot.StartTime
                    : null,
                CancelledAt = reservation.StatusHistory
                    .Where(history =>
                        history.NewStatusId == (int)ReservationStatusCode.Cancelled)
                    .Max(history => (DateTime?)history.ChangedAt),
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (ended is null)
        {
            return;
        }

        await refunds.RecordAsync(
            new CancelledBooking(
                reservationId,
                ended.CreatedAt,
                ended.CheckInDate?.ToDateTime(TimeOnly.MinValue) ?? ended.SlotStartTime!.Value,
                ended.CancelledAt ?? DateTime.UtcNow),
            cancellationToken);
    }
}
