using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IAccommodationPhotoService
{
    Task<PagedResult<AccommodationPhotoResponse>> SearchAsync(
        int accommodationId,
        PagedRequest request,
        CancellationToken cancellationToken);

    Task<AccommodationPhotoResponse> GetAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken);

    Task<ImageContent> GetContentAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken);

    Task<AccommodationPhotoResponse> AddAsync(
        int accommodationId,
        byte[] content,
        CancellationToken cancellationToken);

    Task<AccommodationPhotoResponse> SetCoverAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken);

    Task DeleteAsync(int accommodationId, int photoId, CancellationToken cancellationToken);
}
