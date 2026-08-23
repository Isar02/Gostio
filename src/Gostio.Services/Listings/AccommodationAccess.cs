using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class AccommodationAccess(GostioDbContext db, ICurrentUser currentUser)
    : ListingAccess<Accommodation>(db, currentUser)
{
    protected override string Noun => "accommodation";

    public override Task LockAsync(int listingId, CancellationToken cancellationToken) =>
        Db.Database.ExecuteSqlAsync(
            $"""
            SELECT TOP 1 1 FROM [Accommodations] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Id] = {listingId}
            """,
            cancellationToken);
}
