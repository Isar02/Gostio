using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Favorites;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/favorites")]
[Authorize]
public sealed class FavoritesController(IFavoriteService favorites) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<FavoriteResponse>> Search(
        [FromQuery] FavoriteSearchRequest search,
        CancellationToken cancellationToken) =>
        favorites.SearchAsync(search, cancellationToken);
}
