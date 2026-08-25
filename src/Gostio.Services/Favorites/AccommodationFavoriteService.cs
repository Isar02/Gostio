using System.Linq.Expressions;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;

namespace Gostio.Services.Favorites;

internal sealed class AccommodationFavoriteService(
    GostioDbContext db,
    ICurrentUser currentUser,
    AccommodationAccess access)
    : ListingFavoriteService<Accommodation>(db, currentUser, access), IAccommodationFavoriteService
{
    protected override Expression<Func<Favorite, bool>> PointsAt(int listingId) =>
        favorite => favorite.AccommodationId == listingId;

    protected override Favorite NewFavorite(int listingId) =>
        new() { AccommodationId = listingId };
}
