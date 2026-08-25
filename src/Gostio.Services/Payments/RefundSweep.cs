using Gostio.Model.Enums;
using Gostio.Model.Validation;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Gostio.Services.Payments;

internal sealed record OwedRefund(
    int Id,
    int PaymentId,
    int ReservationId,
    string IntentId,
    decimal Amount,
    string Currency,
    string? StripeRefundId);

internal sealed record RefundAnswer(GatewayRefund Refund, bool Sent);

// The other half of a refund. The cancellation writes what is owed and this
// hands it over: a row with no refund at the processor is sent, and one that has
// been sent but has not resolved is asked about again. Both end in the same
// write, and that write names `Pending`, so a refund another pass resolved is
// left alone and no refund is recorded two different ways.
internal sealed class RefundSweep(
    GostioDbContext db,
    IPaymentGateway gateway,
    IReservationNotices notices,
    WorkerSettings settings,
    ILogger<RefundSweep> logger) : IRefundSweep
{
    public async Task<RefundSweepReport> RunAsync(CancellationToken cancellationToken)
    {
        var owed = await db.Refunds
            .AsNoTracking()
            .Where(refund => refund.Status == RefundStatus.Pending
                && refund.Payment.StripePaymentIntentId != null)
            .OrderBy(refund => refund.Id)
            .Take(settings.RefundSweepBatch)
            .Select(refund => new OwedRefund(
                refund.Id,
                refund.PaymentId,
                refund.Payment.ReservationId,
                refund.Payment.StripePaymentIntentId!,
                refund.Amount,
                refund.Payment.Currency,
                refund.StripeRefundId))
            .ToListAsync(cancellationToken);

        var sent = 0;
        var settled = 0;
        var failed = 0;
        var waiting = 0;

        foreach (var refund in owed)
        {
            var answer = await AskAsync(refund, cancellationToken);

            if (answer is null)
            {
                continue;
            }

            if (answer.Sent)
            {
                sent++;
            }

            switch (await RecordAsync(refund, answer.Refund, cancellationToken))
            {
                case RefundStatus.Succeeded:
                    settled++;
                    break;
                case RefundStatus.Failed:
                    failed++;
                    break;
                default:
                    waiting++;
                    break;
            }
        }

        return new RefundSweepReport(sent, settled, failed, waiting);
    }

    // A processor that cannot be reached leaves the row exactly as it was, so
    // the next pass tries again: losing a pass costs a delay, while giving up on
    // the row would cost the guest their money. A row with an id is asked about;
    // a row without one is looked for before it is sent, because a send whose
    // answer never came back leaves the id absent here while the refund exists
    // there, and the idempotency key that would have caught the resend is only
    // kept for a day. Past that day a blind resend is a second refund, which is
    // the one mistake here that spends money twice.
    private async Task<RefundAnswer?> AskAsync(
        OwedRefund refund,
        CancellationToken cancellationToken)
    {
        try
        {
            return await AnswerAsync(refund, cancellationToken);
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(
                failure,
                "The refund {RefundId} could not be settled with the processor. It stays owed and "
                    + "the next pass tries again.",
                refund.Id);

            return null;
        }
    }

    private async Task<RefundAnswer> AnswerAsync(
        OwedRefund refund,
        CancellationToken cancellationToken)
    {
        if (refund.StripeRefundId is string sentAlready)
        {
            return new RefundAnswer(
                await gateway.ReadRefundAsync(sentAlready, cancellationToken), Sent: false);
        }

        var held = await gateway.FindRefundAsync(
            refund.IntentId, refund.Id, cancellationToken);

        if (held is not null)
        {
            logger.LogWarning(
                "The refund {RefundId} was already held by the processor as {ProcessorId} without "
                    + "this row knowing. It was adopted rather than sent again.",
                refund.Id,
                held.Id);

            return new RefundAnswer(held, Sent: false);
        }

        return new RefundAnswer(
            await gateway.SendRefundAsync(
                new GatewayRefundRequest(
                    refund.Id, refund.IntentId, refund.Amount, refund.Currency),
                cancellationToken),
            Sent: true);
    }

    private async Task<RefundStatus> RecordAsync(
        OwedRefund owed,
        GatewayRefund answer,
        CancellationToken cancellationToken)
    {
        var status = answer.State switch
        {
            GatewayRefundState.Succeeded => RefundStatus.Succeeded,
            GatewayRefundState.Failed => RefundStatus.Failed,
            _ => RefundStatus.Pending,
        };

        var processedAt = status == RefundStatus.Pending ? null : (DateTime?)DateTime.UtcNow;

        var affectedRows = await db.Refunds
            .Where(refund => refund.Id == owed.Id && refund.Status == RefundStatus.Pending)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(refund => refund.StripeRefundId, answer.Id)
                    .SetProperty(refund => refund.Status, status)
                    .SetProperty(refund => refund.ProcessedAt, processedAt)
                    .SetProperty(
                        refund => refund.FailureReason, Reasons.Fit(answer.FailureReason)),
                cancellationToken);

        // Only the pass that settled the row tells the guest.
        if (affectedRows == 1 && status == RefundStatus.Succeeded)
        {
            await notices.RefundedAsync(
                owed.ReservationId, owed.Amount, owed.Currency, cancellationToken);
        }

        if (status == RefundStatus.Failed)
        {
            // The processor will not try this one again and neither will the
            // next pass, so the money goes back another way or not at all. It is
            // logged with everything an operator needs to act on it by hand.
            logger.LogError(
                "The processor turned down the refund {RefundId} of {Amount} {Currency} against "
                    + "the payment {PaymentId} for the reservation {ReservationId}: {Reason}. It "
                    + "has to be paid back another way.",
                owed.Id,
                owed.Amount,
                owed.Currency,
                owed.PaymentId,
                owed.ReservationId,
                answer.FailureReason ?? "no reason given");
        }

        return status;
    }
}
