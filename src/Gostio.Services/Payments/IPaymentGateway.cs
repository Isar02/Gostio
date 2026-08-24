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

// What a card processor has to offer, said without one of its types. The charge
// lives there and the local row only points at it, so everything above this
// interface can be exercised against a processor that never answers the network.
public interface IPaymentGateway
{
    Task<GatewayIntent> CreateIntentAsync(
        GatewayIntentRequest request,
        CancellationToken cancellationToken);

    Task<GatewayIntent> ReadIntentAsync(string intentId, CancellationToken cancellationToken);
}
