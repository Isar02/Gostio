using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Favorites;

public interface IFavoriteService
{
    Task<PagedResult<FavoriteResponse>> SearchAsync(
        FavoriteSearchRequest search,
        CancellationToken cancellationToken);
}
