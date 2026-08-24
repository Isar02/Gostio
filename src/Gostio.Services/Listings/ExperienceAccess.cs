using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class ExperienceAccess(GostioDbContext db, ICurrentUser currentUser)
    : ListingAccess<Experience>(db, currentUser)
{
    protected override string Noun => "experience";

    public override Task LockAsync(int listingId, CancellationToken cancellationToken) =>
        Db.Database.ExecuteSqlAsync(
            $"""
            SELECT TOP 1 1 FROM [Experiences] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Id] = {listingId}
            """,
            cancellationToken);
}
