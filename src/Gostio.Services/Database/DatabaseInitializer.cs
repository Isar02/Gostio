using Gostio.Services.Configuration;
using Gostio.Services.Database.Seeding;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Database;

public static class DatabaseInitializer
{
    public static async Task InitialiseDatabaseAsync(
        this IServiceProvider services,
        AppSettings settings,
        CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();

        var db = scope.ServiceProvider.GetRequiredService<GostioDbContext>();

        await db.Database.MigrateAsync(cancellationToken);
        await DatabaseSeeder.SeedAsync(db, settings, cancellationToken);
    }
}
