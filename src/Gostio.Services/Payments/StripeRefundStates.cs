namespace Gostio.Services.Payments;

public static class StripeRefundStates
{
    // A card refund never comes back cancelled or requiring action from the
    // payer, so neither has a state of its own: an unresolved refund is pending
    // and a cancelled one is a refund that did not happen. As with an intent, a
    // status this does not know stops the call rather than picking a neighbour.
    public static GatewayRefundState Of(string status) => status switch
    {
        "pending" or "requires_action" => GatewayRefundState.Pending,
        "succeeded" => GatewayRefundState.Succeeded,
        "failed" or "canceled" => GatewayRefundState.Failed,
        _ => throw new InvalidOperationException(
            $"Stripe reported the refund status '{status}', which this application does not "
                + "know how to record. Nothing was changed."),
    };
}
