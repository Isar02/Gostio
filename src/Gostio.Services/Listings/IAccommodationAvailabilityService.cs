using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IAccommodationAvailabilityService
{
    Task<PagedResult<AccommodationAvailabilityResponse>> SearchAsync(
        int accommodationId,
        AccommodationAvailabilitySearchRequest search,
        CancellationToken cancellationToken);

    Task<AccommodationAvailabilityResponse> GetAsync(
        int accommodationId,
        int availabilityId,
        CancellationToken cancellationToken);

    Task<AccommodationAvailabilityResponse> AddAsync(
        int accommodationId,
        AccommodationAvailabilityRequest request,
        CancellationToken cancellationToken);

    Task DeleteAsync(int accommodationId, int availabilityId, CancellationToken cancellationToken);
}
