namespace Gostio.Services.Payments;

public static class StripeIntentStates
{
    // A declined card leaves the intent reusable, which is why every unfinished
    // status folds into one state and why a decline never ends a payment row.
    // A status this does not know stops the call rather than being read as the
    // nearest one: guessing here records a charge that never happened.
    public static GatewayIntentState Of(string status) => status switch
    {
        "requires_payment_method" or "requires_confirmation" or "requires_action"
            or "processing" or "requires_capture" => GatewayIntentState.Open,
        "succeeded" => GatewayIntentState.Succeeded,
        "canceled" => GatewayIntentState.Cancelled,
        _ => throw new InvalidOperationException(
            $"Stripe reported the payment intent status '{status}', which this application "
                + "does not know how to record. Nothing was changed."),
    };
}
