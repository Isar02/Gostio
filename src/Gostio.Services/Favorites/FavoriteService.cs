using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Favorites;

internal sealed class FavoriteService(GostioDbContext db, ICurrentUser currentUser)
    : IFavoriteService
{
    public Task<PagedResult<FavoriteResponse>> SearchAsync(
        FavoriteSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(Mine(), search)
            .OrderByDescending(favorite => favorite.CreatedAt)
            .ThenByDescending(favorite => favorite.Id)
            .ToPagedResultAsync(search, FavoriteProjection.Of, cancellationToken);

    private static IQueryable<Favorite> Matching(
        IQueryable<Favorite> query,
        FavoriteSearchRequest search) =>
        search.Target switch
        {
            SearchTarget.Accommodations =>
                query.Where(favorite => favorite.AccommodationId != null),
            SearchTarget.Experiences => query.Where(favorite => favorite.ExperienceId != null),
            _ => query,
        };

    private IQueryable<Favorite> Mine()
    {
        var userId = currentUser.RequireUserId();

        return db.Favorites.AsNoTracking().Where(favorite => favorite.UserId == userId);
    }
}
