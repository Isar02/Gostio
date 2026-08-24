using System.Globalization;
using Gostio.Model.Validation;
using Stripe;

namespace Gostio.Services.Payments;

internal sealed class StripePaymentGateway(IStripeClient client) : IPaymentGateway
{
    private const string CardPaymentMethod = "card";

    private const string PaymentMetadataKey = "paymentId";

    private const string ReservationMetadataKey = "reservationId";

    private readonly PaymentIntentService intents = new(client);

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

    public static GatewayIntent Describe(PaymentIntent intent) =>
        new(intent.Id, intent.ClientSecret, StripeIntentStates.Of(intent.Status));

    private static long MinorUnits(decimal amount) =>
        (long)decimal.Round(
            amount * Currencies.MinorUnitsPerUnit, 0, MidpointRounding.AwayFromZero);

    private static string Text(int value) => value.ToString(CultureInfo.InvariantCulture);
}
