using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Reservations;

public interface IReservationMoveService
{
    Task<ReservationResponse> ConfirmAsync(int reservationId, CancellationToken cancellationToken);

    Task<ReservationResponse> CancelAsync(
        int reservationId,
        ReservationCancelRequest request,
        CancellationToken cancellationToken);
}
