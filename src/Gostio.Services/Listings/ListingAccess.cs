using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal abstract class ListingAccess<TListing>(GostioDbContext db, ICurrentUser currentUser)
    where TListing : class, IListing
{
    protected GostioDbContext Db { get; } = db;

    protected abstract string Noun { get; }

    private DbSet<TListing> Set => Db.Set<TListing>();

    // A withdrawn listing still belongs to its host and is still an
    // administrator's to manage, but nobody else browses it, and to them it
    // answers 404 rather than 403: an id nobody may read must not become a way
    // of learning that it exists.
    public IQueryable<TListing> Visible(IQueryable<TListing> query)
    {
        if (currentUser.IsInRole(RoleNames.Administrator))
        {
            return query;
        }

        var callerId = currentUser.UserId;

        return query.Where(listing => listing.IsActive || listing.HostId == callerId);
    }

    // Gates a child query on its listing inside the statement that reads it.
    // Callers have to correlate it with the child row rather than close over an
    // id: an uncorrelated subquery is one Entity Framework runs on its own,
    // which puts the check back in a statement of its own and reopens the gap.
    public IQueryable<TListing> VisibleListings() => Visible(Set.AsNoTracking());

    // Writers on one listing queue here: under read committed snapshot two of
    // them otherwise read the same rows and collide on the key they both write.
    // Each listing names its own table, because a table name is not a parameter
    // and interpolating one would send it as a string instead.
    public abstract Task LockAsync(int listingId, CancellationToken cancellationToken);

    public async Task RequireVisibleAsync(int listingId, CancellationToken cancellationToken)
    {
        var visible = await VisibleListings()
            .AnyAsync(listing => listing.Id == listingId, cancellationToken);

        if (!visible)
        {
            throw Missing(listingId);
        }
    }

    // Read as a projection rather than loaded: a tracked row is what breaks a
    // single-statement delete that follows it.
    public async Task RequireOwnedAsync(int listingId, CancellationToken cancellationToken)
    {
        var hostId = await Set
            .AsNoTracking()
            .Where(listing => listing.Id == listingId)
            .Select(listing => (int?)listing.HostId)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(listingId);

        RequireOwnerOrAdministrator(hostId);
    }

    public void RequireOwnerOrAdministrator(int hostId)
    {
        if (currentUser.RequireUserId() == hostId
            || currentUser.IsInRole(RoleNames.Administrator))
        {
            return;
        }

        throw new ForbiddenException("A host may only work on their own listings.");
    }

    public NotFoundException Missing(int listingId) => new($"No {Noun} has the id {listingId}.");
}
