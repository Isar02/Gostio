using System.Linq.Expressions;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Favorites;

internal abstract class ListingFavoriteService<TListing>(
    GostioDbContext db,
    ICurrentUser currentUser,
    ListingAccess<TListing> access) : IListingFavoriteService
    where TListing : class, IListing
{
    protected abstract Expression<Func<Favorite, bool>> PointsAt(int listingId);

    protected abstract Favorite NewFavorite(int listingId);

    public async Task<FavoriteResponse> AddAsync(
        int listingId,
        CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();

        await access.RequireVisibleAsync(listingId, cancellationToken);

        var kept = await Kept(userId, listingId)
            .Select(FavoriteProjection.Of)
            .FirstOrDefaultAsync(cancellationToken);

        if (kept is not null)
        {
            return kept;
        }

        var favorite = NewFavorite(listingId);

        favorite.UserId = userId;
        favorite.CreatedAt = DateTime.UtcNow;

        db.Favorites.Add(favorite);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            db.Entry(favorite).State = EntityState.Detached;
        }

        return await Kept(userId, listingId)
            .Select(FavoriteProjection.Of)
            .FirstAsync(cancellationToken);
    }

    public async Task RemoveAsync(int listingId, CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();

        await db.Favorites
            .Where(favorite => favorite.UserId == userId)
            .Where(PointsAt(listingId))
            .ExecuteDeleteAsync(cancellationToken);
    }

    private IQueryable<Favorite> Kept(int userId, int listingId) =>
        db.Favorites
            .AsNoTracking()
            .Where(favorite => favorite.UserId == userId)
            .Where(PointsAt(listingId));
}
