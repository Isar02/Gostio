using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Reservations;

public interface IReservationService
{
    Task<ReservationResponse> CreateAsync(
        ReservationCreateRequest request,
        CancellationToken cancellationToken);

    Task<ReservationResponse> GetAsync(int reservationId, CancellationToken cancellationToken);
}
