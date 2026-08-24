using Gostio.Services.Configuration;
using Gostio.Services.Reservations;

namespace Gostio.Worker;

public sealed class ReservationSweepService(
    IServiceScopeFactory scopes,
    ILogger<ReservationSweepService> logger,
    WorkerSettings settings) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation(
            "Reservation sweep started, one pass every {Interval}.",
            settings.ReservationSweepInterval);

        using var timer = new PeriodicTimer(settings.ReservationSweepInterval);

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
            logger.LogInformation("Reservation sweep stopped with the host.");
        }
    }

    private async Task SweepAsync(CancellationToken stoppingToken)
    {
        try
        {
            await using var scope = scopes.CreateAsyncScope();

            Report(await scope.ServiceProvider
                .GetRequiredService<IReservationSweep>()
                .RunAsync(stoppingToken));
        }
        catch (Exception failure) when (!stoppingToken.IsCancellationRequested)
        {
            logger.LogError(failure, "A reservation sweep failed. The next pass still runs.");
        }
    }

    private void Report(ReservationSweepReport swept)
    {
        if (swept.Expired + swept.Completed + swept.Skipped == 0)
        {
            logger.LogDebug("A reservation sweep found nothing to move.");

            return;
        }

        logger.LogInformation(
            "A reservation sweep expired {Expired} holds, completed {Completed} bookings and "
                + "left {Skipped} that had already moved.",
            swept.Expired,
            swept.Completed,
            swept.Skipped);
    }
}
