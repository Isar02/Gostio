using Gostio.Services.Payments;

namespace Gostio.IntegrationTests;

// A processor that keeps its charges in memory and keys them the way the real
// one is asked to: on the payment row. Two calls carrying the same payment get
// the same charge back, which is the guarantee the service leans on.
internal sealed record HeldRefund(string IntentId, GatewayRefundState State);

public sealed class FakePaymentGateway : IPaymentGateway
{
    private readonly Dictionary<string, GatewayIntentState> states = [];

    private readonly Dictionary<string, HeldRefund> refunds = [];

    private readonly List<int> created = [];

    private readonly List<int> sent = [];

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

    public IReadOnlyList<int> Sent
    {
        get
        {
            lock (gate)
            {
                return [.. sent];
            }
        }
    }

    // Fails whatever it is asked to refund next, once, so a test can watch a
    // refund the processor turned down without reaching into the sweep.
    public bool RefusesTheNextRefund { get; set; }

    public GatewayRefundState RefundLandsAs { get; set; } = GatewayRefundState.Succeeded;

    public static string IntentOf(int paymentId) => $"pi_test_{paymentId}";

    public static string RefundOf(int refundId) => $"re_test_{refundId}";

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

    public Task<GatewayRefund> SendRefundAsync(
        GatewayRefundRequest request,
        CancellationToken cancellationToken)
    {
        var refundId = RefundOf(request.RefundId);

        lock (gate)
        {
            if (RefusesTheNextRefund)
            {
                RefusesTheNextRefund = false;

                throw new InvalidOperationException("The processor refused this refund.");
            }

            if (refunds.TryAdd(refundId, new HeldRefund(request.IntentId, RefundLandsAs)))
            {
                sent.Add(request.RefundId);
            }

            return Task.FromResult(Refund(refundId));
        }
    }

    public Task<GatewayRefund> ReadRefundAsync(
        string refundId,
        CancellationToken cancellationToken)
    {
        lock (gate)
        {
            return refunds.ContainsKey(refundId)
                ? Task.FromResult(Refund(refundId))
                : throw new InvalidOperationException($"No refund is known as {refundId}.");
        }
    }

    public void SettleRefund(int refundId, GatewayRefundState state)
    {
        lock (gate)
        {
            var known = RefundOf(refundId);

            refunds[known] = refunds.TryGetValue(known, out var held)
                ? held with { State = state }
                : throw new InvalidOperationException($"No refund is known as {known}.");
        }
    }

    // A refund the processor accepted and whose answer never came back. The row
    // that asked for it has no id, and only the metadata connects the two.
    public void HoldRefundNobodyHeardAbout(
        int refundId,
        int paymentId,
        GatewayRefundState state = GatewayRefundState.Succeeded)
    {
        lock (gate)
        {
            refunds[RefundOf(refundId)] = new HeldRefund(IntentOf(paymentId), state);
        }
    }

    public Task<GatewayRefund?> FindRefundAsync(
        string intentId,
        int refundId,
        CancellationToken cancellationToken)
    {
        var candidate = RefundOf(refundId);

        lock (gate)
        {
            return Task.FromResult(
                refunds.TryGetValue(candidate, out var held) && held.IntentId == intentId
                    ? Refund(candidate)
                    : null);
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

    private GatewayRefund Refund(string refundId) =>
        new(
            refundId,
            refunds[refundId].State,
            refunds[refundId].State == GatewayRefundState.Failed
                ? "The bank turned it down."
                : null);
}
