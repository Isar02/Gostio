namespace Gostio.Services.Payments;

public sealed record RefundSweepReport(int Sent, int Settled, int Failed, int Waiting);

public interface IRefundSweep
{
    Task<RefundSweepReport> RunAsync(CancellationToken cancellationToken);
}
