using Gostio.Model.Enums;

namespace Gostio.Services.Reservations;

// Raised after the change it announces has committed, never inside it.
public interface IReservationNotices
{
    Task CreatedAsync(int reservationId, CancellationToken cancellationToken);

    Task MovedAsync(
        int reservationId,
        ReservationStatusCode to,
        CancellationToken cancellationToken);

    Task PaidAsync(
        int reservationId,
        decimal amount,
        string currency,
        CancellationToken cancellationToken);

    Task RefundedAsync(
        int reservationId,
        decimal amount,
        string currency,
        CancellationToken cancellationToken);
}
