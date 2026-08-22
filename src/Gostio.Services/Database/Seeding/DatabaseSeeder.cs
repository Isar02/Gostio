using Gostio.Services.Configuration;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Database.Seeding;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(
        GostioDbContext db,
        AppSettings settings,
        CancellationToken cancellationToken = default)
    {
        // Each area saves so the next can read its ids. Without one transaction over
        // all of them, a partial seed leaves the guard below seeing users for good.
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        if (await db.Users.AnyAsync(cancellationToken))
        {
            return;
        }

        var now = DateTime.UtcNow;

        var lookups = await LookupSeed.SeedAsync(db, cancellationToken);

        var users = await UserSeed.SeedAsync(
            db, lookups, settings.Seed.DefaultPassword, now, cancellationToken);

        var listings = await ListingSeed.SeedAsync(db, lookups, users, now, cancellationToken);

        var bookings = await BookingSeed.SeedAsync(
            db, users, listings, settings.Stripe.Currency, now, cancellationToken);

        await EngagementSeed.SeedAsync(
            db, lookups, users, listings, bookings, now, cancellationToken);

        await transaction.CommitAsync(cancellationToken);
    }
}
