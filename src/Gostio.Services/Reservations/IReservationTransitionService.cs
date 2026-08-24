using Gostio.Model.Enums;

namespace Gostio.Services.Reservations;

public interface IReservationTransitionService
{
    Task<DateTime> MoveAsync(
        int reservationId,
        int fromStatusId,
        ReservationStatusCode to,
        int? changedByUserId,
        string? reason,
        CancellationToken cancellationToken);
}
