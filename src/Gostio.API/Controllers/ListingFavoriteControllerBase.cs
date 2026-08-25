using Gostio.Model.Responses;
using Gostio.Services.Favorites;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[Authorize]
public abstract class ListingFavoriteControllerBase<TService>(TService favorites) : ControllerBase
    where TService : IListingFavoriteService
{
    [HttpPut]
    public Task<FavoriteResponse> Add(int listingId, CancellationToken cancellationToken) =>
        favorites.AddAsync(listingId, cancellationToken);

    [HttpDelete]
    public async Task<IActionResult> Remove(int listingId, CancellationToken cancellationToken)
    {
        await favorites.RemoveAsync(listingId, cancellationToken);

        return NoContent();
    }
}
