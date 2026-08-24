using Gostio.Services.Configuration;
using Gostio.Services.Payments;

namespace Gostio.Worker;

public sealed class RefundSweepService(
    IServiceScopeFactory scopes,
    ILogger<RefundSweepService> logger,
    WorkerSettings settings) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation(
            "Refund sweep started, one pass every {Interval}.", settings.RefundSweepInterval);

        using var timer = new PeriodicTimer(settings.RefundSweepInterval);

        try
        {
            do
            {
                await SweepAsync(stoppingToken);
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException)
        {
            logger.LogInformation("Refund sweep stopped with the host.");
        }
    }

    private async Task SweepAsync(CancellationToken stoppingToken)
    {
        try
        {
            await using var scope = scopes.CreateAsyncScope();

            Report(await scope.ServiceProvider
                .GetRequiredService<IRefundSweep>()
                .RunAsync(stoppingToken));
        }
        catch (Exception failure) when (!stoppingToken.IsCancellationRequested)
        {
            logger.LogError(failure, "A refund sweep failed. The next pass still runs.");
        }
    }

    private void Report(RefundSweepReport swept)
    {
        if (swept.Sent + swept.Settled + swept.Failed + swept.Waiting == 0)
        {
            logger.LogDebug("A refund sweep found nothing owed.");

            return;
        }

        logger.LogInformation(
            "A refund sweep sent {Sent} refunds, settled {Settled}, recorded {Failed} the "
                + "processor turned down and left {Waiting} still in flight.",
            swept.Sent,
            swept.Settled,
            swept.Failed,
            swept.Waiting);
    }
}
