using Gostio.Model.Responses;

namespace Gostio.Services.Favorites;

public interface IListingFavoriteService
{
    Task<FavoriteResponse> AddAsync(int listingId, CancellationToken cancellationToken);

    Task RemoveAsync(int listingId, CancellationToken cancellationToken);
}
