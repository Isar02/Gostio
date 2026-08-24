using System.Globalization;
using Gostio.Model.Validation;
using Stripe;

namespace Gostio.Services.Payments;

internal sealed class StripePaymentGateway(IStripeClient client) : IPaymentGateway
{
    private const string CardPaymentMethod = "card";

    private const string PaymentMetadataKey = "paymentId";

    private const string ReservationMetadataKey = "reservationId";

    private const string RefundMetadataKey = "refundId";

    // One charge never carries enough refunds to page, and a page that somehow
    // missed one would send a second, so this is deliberately the largest Stripe
    // allows rather than a number that only usually fits.
    private const int ListPageSize = 100;

    private readonly PaymentIntentService intents = new(client);

    private readonly Stripe.RefundService refunds = new(client);

    public async Task<GatewayIntent> CreateIntentAsync(
        GatewayIntentRequest request,
        CancellationToken cancellationToken)
    {
        var options = new PaymentIntentCreateOptions
        {
            Amount = MinorUnits(request.Amount),
            Currency = request.Currency,
            PaymentMethodTypes = [CardPaymentMethod],
            Metadata = new Dictionary<string, string>
            {
                [PaymentMetadataKey] = Text(request.PaymentId),
                [ReservationMetadataKey] = Text(request.ReservationId),
            },
        };

        // Keyed on the payment row, so a create whose answer was lost returns
        // the intent the first attempt made rather than charging for a second.
        var retries = new RequestOptions { IdempotencyKey = $"payment-{request.PaymentId}" };

        return Describe(await intents.CreateAsync(options, retries, cancellationToken));
    }

    public async Task<GatewayIntent> ReadIntentAsync(
        string intentId,
        CancellationToken cancellationToken) =>
        Describe(await intents.GetAsync(
            intentId, options: null, requestOptions: null, cancellationToken));

    public async Task<GatewayRefund> SendRefundAsync(
        GatewayRefundRequest request,
        CancellationToken cancellationToken)
    {
        var options = new RefundCreateOptions
        {
            PaymentIntent = request.IntentId,
            Amount = MinorUnits(request.Amount),
            Metadata = new Dictionary<string, string>
            {
                [RefundMetadataKey] = Text(request.RefundId),
            },
        };

        var retries = new RequestOptions { IdempotencyKey = $"refund-{request.RefundId}" };

        return Describe(await refunds.CreateAsync(options, retries, cancellationToken));
    }

    public async Task<GatewayRefund> ReadRefundAsync(
        string refundId,
        CancellationToken cancellationToken) =>
        Describe(await refunds.GetAsync(
            refundId, options: null, requestOptions: null, cancellationToken));

    // Matched on the metadata rather than on the amount, because two refunds of
    // the same amount against one charge are indistinguishable by anything else.
    public async Task<GatewayRefund?> FindRefundAsync(
        string intentId,
        int refundId,
        CancellationToken cancellationToken)
    {
        var options = new RefundListOptions { PaymentIntent = intentId, Limit = ListPageSize };

        var held = await refunds.ListAsync(options, requestOptions: null, cancellationToken);

        var mine = held.FirstOrDefault(refund =>
            refund.Metadata is not null
            && refund.Metadata.TryGetValue(RefundMetadataKey, out var written)
            && written == Text(refundId));

        return mine is null ? null : Describe(mine);
    }

    public static GatewayIntent Describe(PaymentIntent intent) =>
        new(intent.Id, intent.ClientSecret, StripeIntentStates.Of(intent.Status));

    public static GatewayRefund Describe(Refund refund) =>
        new(refund.Id, StripeRefundStates.Of(refund.Status), refund.FailureReason);

    private static long MinorUnits(decimal amount) =>
        (long)decimal.Round(
            amount * Currencies.MinorUnitsPerUnit, 0, MidpointRounding.AwayFromZero);

    private static string Text(int value) => value.ToString(CultureInfo.InvariantCulture);
}
