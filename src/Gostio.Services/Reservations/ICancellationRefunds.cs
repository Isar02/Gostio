namespace Gostio.Services.Reservations;

public sealed record CancelledBooking(
    int ReservationId,
    DateTime CreatedAt,
    DateTime StartsAt,
    DateTime CancelledAt);

// What a cancellation owes back. The reservation side asks, because it is what
// cancels; the payment side answers, because it is what knows the amount that
// was actually charged. Stated here so the dependency runs one way.
public interface ICancellationRefunds
{
    Task RecordAsync(CancelledBooking booking, CancellationToken cancellationToken);
}
