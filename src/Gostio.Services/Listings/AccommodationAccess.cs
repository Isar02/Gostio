using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class AccommodationAccess(GostioDbContext db, ICurrentUser currentUser)
{
    // A withdrawn listing still belongs to its host and is still an
    // administrator's to manage, but nobody else browses it.
    public IQueryable<Accommodation> Visible(IQueryable<Accommodation> query)
    {
        if (currentUser.IsInRole(RoleNames.Administrator))
        {
            return query;
        }

        var callerId = currentUser.UserId;

        return query.Where(
            accommodation => accommodation.IsActive || accommodation.HostId == callerId);
    }

    // Answers 404 rather than 403 for a listing the caller cannot see, so an id
    // nobody may read does not become a way of learning that it exists.
    public async Task RequireVisibleAsync(int accommodationId, CancellationToken cancellationToken)
    {
        var visible = await Visible(db.Accommodations.AsNoTracking())
            .AnyAsync(accommodation => accommodation.Id == accommodationId, cancellationToken);

        if (!visible)
        {
            throw Missing(accommodationId);
        }
    }

    // Read as a projection rather than loaded: a tracked row is what breaks a
    // single-statement delete that follows it.
    public async Task RequireOwnedAsync(int accommodationId, CancellationToken cancellationToken)
    {
        var hostId = await db.Accommodations
            .AsNoTracking()
            .Where(accommodation => accommodation.Id == accommodationId)
            .Select(accommodation => (int?)accommodation.HostId)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(accommodationId);

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

    public static NotFoundException Missing(int accommodationId) =>
        new($"No accommodation has the id {accommodationId}.");
}
