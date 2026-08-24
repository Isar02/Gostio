namespace Gostio.Services.Payments;

public enum GatewayIntentState
{
    Open,
    Succeeded,
    Cancelled
}

public sealed record GatewayIntentRequest(
    int PaymentId,
    int ReservationId,
    decimal Amount,
    string Currency);

public sealed record GatewayIntent(string Id, string? ClientSecret, GatewayIntentState State);

public enum GatewayRefundState
{
    Pending,
    Succeeded,
    Failed
}

public sealed record GatewayRefundRequest(
    int RefundId,
    string IntentId,
    decimal Amount,
    string Currency);

public sealed record GatewayRefund(string Id, GatewayRefundState State, string? FailureReason);

// What a card processor has to offer, said without one of its types. The charge
// lives there and the local row only points at it, so everything above this
// interface can be exercised against a processor that never answers the network.
public interface IPaymentGateway
{
    Task<GatewayIntent> CreateIntentAsync(
        GatewayIntentRequest request,
        CancellationToken cancellationToken);

    Task<GatewayIntent> ReadIntentAsync(string intentId, CancellationToken cancellationToken);

    Task<GatewayRefund> SendRefundAsync(
        GatewayRefundRequest request,
        CancellationToken cancellationToken);

    Task<GatewayRefund> ReadRefundAsync(string refundId, CancellationToken cancellationToken);

    // The refund the processor already holds against this charge for this row,
    // or nothing. It is how a send whose answer was lost is found again once the
    // idempotency key that would have caught it has expired.
    Task<GatewayRefund?> FindRefundAsync(
        string intentId,
        int refundId,
        CancellationToken cancellationToken);
}
