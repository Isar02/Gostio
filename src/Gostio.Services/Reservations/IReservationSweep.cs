namespace Gostio.Services.Reservations;

public sealed record ReservationSweepReport(int Expired, int Completed, int Skipped);

public interface IReservationSweep
{
    Task<ReservationSweepReport> RunAsync(CancellationToken cancellationToken);
}
