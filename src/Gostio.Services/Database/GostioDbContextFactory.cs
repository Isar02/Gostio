using Gostio.Services.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Gostio.Services.Database;

/// <summary>
/// Lets the EF Core tooling build a context without starting the API, so
/// migrations are created and applied from the project that owns the model:
///
///     dotnet ef migrations add &lt;Name&gt; --project src/Gostio.Services
///
/// The connection string comes from the same loader the running application
/// uses, which keeps the .env file the only source of configuration.
/// </summary>
public sealed class GostioDbContextFactory : IDesignTimeDbContextFactory<GostioDbContext>
{
    public GostioDbContext CreateDbContext(string[] args)
    {
        var settings = AppSettingsLoader.Load();

        var options = new DbContextOptionsBuilder<GostioDbContext>()
            .UseSqlServer(settings.Database.ConnectionString)
            .Options;

        return new GostioDbContext(options);
    }
}
