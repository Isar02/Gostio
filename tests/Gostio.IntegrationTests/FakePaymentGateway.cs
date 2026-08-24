using Gostio.Services.Payments;

namespace Gostio.IntegrationTests;

// A processor that keeps its charges in memory and keys them the way the real
// one is asked to: on the payment row. Two calls carrying the same payment get
// the same charge back, which is the guarantee the service leans on.
public sealed class FakePaymentGateway : IPaymentGateway
{
    private readonly Dictionary<string, GatewayIntentState> states = [];

    private readonly List<int> created = [];

    private readonly Lock gate = new();

    public IReadOnlyList<int> Created
    {
        get
        {
            lock (gate)
            {
                return [.. created];
            }
        }
    }

    public static string IntentOf(int paymentId) => $"pi_test_{paymentId}";

    public Task<GatewayIntent> CreateIntentAsync(
        GatewayIntentRequest request,
        CancellationToken cancellationToken)
    {
        var intentId = IntentOf(request.PaymentId);

        lock (gate)
        {
            if (states.TryAdd(intentId, GatewayIntentState.Open))
            {
                created.Add(request.PaymentId);
            }

            return Task.FromResult(Intent(intentId));
        }
    }

    public Task<GatewayIntent> ReadIntentAsync(
        string intentId,
        CancellationToken cancellationToken)
    {
        lock (gate)
        {
            return states.ContainsKey(intentId)
                ? Task.FromResult(Intent(intentId))
                : throw new InvalidOperationException($"No charge is known as {intentId}.");
        }
    }

    public void Settle(int paymentId, GatewayIntentState state)
    {
        lock (gate)
        {
            states[IntentOf(paymentId)] = state;
        }
    }

    private GatewayIntent Intent(string intentId) =>
        new(intentId, $"{intentId}_secret", states[intentId]);

}
