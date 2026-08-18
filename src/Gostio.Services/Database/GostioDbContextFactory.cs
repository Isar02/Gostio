using Gostio.Services.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Gostio.Services.Database;

// Lets the EF tooling build a context without starting the API, from the same
// configuration the running application uses.
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
