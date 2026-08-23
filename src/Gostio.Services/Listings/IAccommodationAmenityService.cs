using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IAccommodationAmenityService
{
    Task<IReadOnlyList<LookupResponse>> GetAsync(
        int accommodationId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<LookupResponse>> SetAsync(
        int accommodationId,
        AccommodationAmenitiesRequest request,
        CancellationToken cancellationToken);
}
