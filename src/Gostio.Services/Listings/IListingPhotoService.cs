using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IListingPhotoService
{
    Task<PagedResult<ListingPhotoResponse>> SearchAsync(
        int listingId,
        PagedRequest request,
        CancellationToken cancellationToken);

    Task<ListingPhotoResponse> GetAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken);

    Task<ImageContent> GetContentAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken);

    Task<ListingPhotoResponse> AddAsync(
        int listingId,
        ImageUpload upload,
        CancellationToken cancellationToken);

    Task<ListingPhotoResponse> SetCoverAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken);

    Task DeleteAsync(int listingId, int photoId, CancellationToken cancellationToken);
}
