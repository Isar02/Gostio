using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Database;

/// <summary>
/// The single database context for the whole system.
///
/// Two rules hold across every entity configuration in this assembly:
/// every relationship states its <c>OnDelete</c> behaviour explicitly, and
/// nothing relies on the conventional cascade, because the reservation graph
/// reaches users through more than one path and SQL Server rejects multiple
/// cascade paths to the same table.
/// </summary>
public class GostioDbContext(DbContextOptions<GostioDbContext> options) : DbContext(options)
{
    /// <summary>
    /// Applied to every string column that does not set its own length, so an
    /// unconfigured property can never silently become <c>nvarchar(max)</c>.
    /// </summary>
    private const int DefaultStringLength = 256;

    private const int MoneyPrecision = 18;
    private const int MoneyScale = 2;

    public DbSet<Country> Countries => Set<Country>();

    public DbSet<City> Cities => Set<City>();

    public DbSet<AccommodationType> AccommodationTypes => Set<AccommodationType>();

    public DbSet<AccommodationCategory> AccommodationCategories => Set<AccommodationCategory>();

    public DbSet<ExperienceCategory> ExperienceCategories => Set<ExperienceCategory>();

    public DbSet<Amenity> Amenities => Set<Amenity>();

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        configurationBuilder.Properties<string>().HaveMaxLength(DefaultStringLength);
        configurationBuilder.Properties<decimal>().HavePrecision(MoneyPrecision, MoneyScale);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GostioDbContext).Assembly);
    }
}
