using Gostio.Model.Enums;

namespace Gostio.Services.Reservations;

public interface IReservationTransitionService
{
    Task ChangeAsync(
        int reservationId,
        ReservationStatusCode to,
        int? changedByUserId,
        string? reason,
        CancellationToken cancellationToken);
}
