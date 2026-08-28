using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IAccommodationAmenityService
{
    Task<PagedResult<LookupResponse>> GetAsync(
        int accommodationId,
        PagedRequest request,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<LookupResponse>> SetAsync(
        int accommodationId,
        AccommodationAmenitiesRequest request,
        CancellationToken cancellationToken);
}
