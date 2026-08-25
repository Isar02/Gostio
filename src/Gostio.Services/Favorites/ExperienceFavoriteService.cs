using System.Linq.Expressions;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;

namespace Gostio.Services.Favorites;

internal sealed class ExperienceFavoriteService(
    GostioDbContext db,
    ICurrentUser currentUser,
    ExperienceAccess access)
    : ListingFavoriteService<Experience>(db, currentUser, access), IExperienceFavoriteService
{
    protected override Expression<Func<Favorite, bool>> PointsAt(int listingId) =>
        favorite => favorite.ExperienceId == listingId;

    protected override Favorite NewFavorite(int listingId) =>
        new() { ExperienceId = listingId };
}
