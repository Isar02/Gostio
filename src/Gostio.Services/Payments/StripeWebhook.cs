using Gostio.Model.Exceptions;
using Gostio.Services.Configuration;
using Microsoft.Extensions.Logging;
using Stripe;

namespace Gostio.Services.Payments;

internal sealed class StripeWebhook(
    IPaymentSettlement settlement,
    StripeSettings stripe,
    ILogger<StripeWebhook> logger) : IPaymentWebhook
{
    private const string Succeeded = "payment_intent.succeeded";

    private const string Failed = "payment_intent.payment_failed";

    private const string Cancelled = "payment_intent.canceled";

    public async Task ReceiveAsync(
        string payload,
        string? signature,
        CancellationToken cancellationToken)
    {
        var report = OutcomeOf(Verified(payload, signature));

        if (report is null)
        {
            return;
        }

        await settlement.SettleAsync(report, cancellationToken);
    }

    // Nothing is read out of the body before the signature over it holds: no
    // token guards this endpoint, so this is the whole of its authentication.
    // The absent header is tested here rather than passed on, because the
    // library dereferences it and would answer a missing header with a 500.
    private Event Verified(string payload, string? signature)
    {
        if (!stripe.CanVerifyAWebhook)
        {
            throw new InvalidOperationException(
                "Verifying a webhook needs STRIPE_WEBHOOK_SECRET in the .env file. Nothing "
                    + "posted here can be believed without it.");
        }

        if (string.IsNullOrWhiteSpace(signature))
        {
            throw Unsigned();
        }

        try
        {
            return EventUtility.ConstructEvent(payload, signature, stripe.WebhookSecret);
        }
        catch (StripeException failure)
        {
            logger.LogWarning(
                failure, "A webhook call arrived without a signature this application accepts.");

            throw Unsigned();
        }
    }

    private static ValidationException Unsigned() =>
        new("signature", "This request did not carry a signature from the payment processor.");

    // Stripe sends far more than the three events this application acts on, and
    // an event it does not know is answered as received rather than refused:
    // a refusal makes the processor retry something that will never be handled.
    private PaymentOutcomeReport? OutcomeOf(Event received)
    {
        var outcome = received.Type switch
        {
            Succeeded => PaymentOutcome.Succeeded,
            Failed => PaymentOutcome.Failed,
            Cancelled => PaymentOutcome.Cancelled,
            _ => (PaymentOutcome?)null,
        };

        if (outcome is not PaymentOutcome known)
        {
            logger.LogDebug("The webhook event {EventType} is not one this application acts on.",
                received.Type);

            return null;
        }

        if (received.Data.Object is not PaymentIntent intent)
        {
            throw new BusinessException(
                $"The webhook event {received.Type} did not carry a payment intent.");
        }

        return new PaymentOutcomeReport(
            intent.Id, known, intent.LastPaymentError?.Message);
    }
}
