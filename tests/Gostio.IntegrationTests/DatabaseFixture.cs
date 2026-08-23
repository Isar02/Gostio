using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Gostio.Services.Lookups;
using Gostio.Services.Users;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

public sealed class DatabaseFixture : IAsyncLifetime
{
    public const string SeededUsername = "integration";

    public const string SeededPassword = "the-seeded-password";

    private const string TestDatabaseSuffix = "_tests";

    private readonly string connectionString;

    private readonly string databaseName;

    public DatabaseFixture()
    {
        var database = AppSettingsLoader.Load().Database;

        databaseName = database.Name + TestDatabaseSuffix;
        connectionString = new SqlConnectionStringBuilder(database.ConnectionString)
        {
            InitialCatalog = databaseName,
        }.ConnectionString;
    }

    public JwtSettings Jwt { get; } = new()
    {
        Key = "an-integration-test-signing-key-long-enough-for-hmac-sha256",
        Issuer = "Gostio.IntegrationTests",
        Audience = "Gostio.IntegrationTests.Clients",
        ExpiresMinutes = 30,
    };

    public async Task InitializeAsync()
    {
        await using var db = CreateContext();

        try
        {
            await db.Database.EnsureDeletedAsync();
            await db.Database.MigrateAsync();
        }
        catch (SqlException failure)
        {
            throw new InvalidOperationException(
                $"The database '{databaseName}' could not be prepared. These tests need the "
                    + "SQL Server the compose file starts: docker compose up -d gostio-db.",
                failure);
        }

        db.Users.Add(NewUser(SeededUsername, "integration@example.com", SeededPassword));

        await db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        await using var db = CreateContext();

        await db.Database.EnsureDeletedAsync();
    }

    // Resolved through the real registrations rather than constructed, so a
    // service the container cannot build fails here as well as at start-up.
    public ServiceProvider BuildServices(
        ICurrentUser? caller = null,
        params IInterceptor[] interceptors)
    {
        var services = new ServiceCollection();

        services.AddScoped(_ => CreateContext(interceptors));
        services.AddScoped(_ => caller ?? new AnonymousUser());
        services.AddGostioLookupServices();
        services.AddGostioListingServices();
        services.AddGostioUserServices();

        return services.BuildServiceProvider();
    }

    public GostioDbContext CreateContext(params IInterceptor[] interceptors) =>
        new(new DbContextOptionsBuilder<GostioDbContext>()
            .UseSqlServer(connectionString)
            .AddInterceptors(interceptors)
            .Options);

    // A test that writes to a user gets one of its own, so the row it counts on
    // is never the row another test has already moved.
    public async Task<int> AddUserAsync(string password, params string[] roles)
    {
        var now = DateTime.UtcNow;
        var roleIds = new List<int>();

        foreach (var role in roles)
        {
            roleIds.Add(await EnsureRoleAsync(role));
        }

        await using var db = CreateContext();

        var name = $"user-{Guid.NewGuid():N}";
        var user = NewUser(name, $"{name}@example.com", password);

        user.UserRoles =
            [.. roleIds.Select(roleId => new UserRole { RoleId = roleId, AssignedAt = now })];

        db.Users.Add(user);
        await db.SaveChangesAsync();

        return user.Id;
    }

    // The reference tables are empty in the migrated database, and more than
    // one test needs the same role to be there without caring who put it there.
    public async Task<int> EnsureRoleAsync(string name)
    {
        await using var db = CreateContext();

        var role = await db.Roles.FirstOrDefaultAsync(candidate => candidate.Name == name);

        if (role is null)
        {
            role = new Role { Name = name };

            db.Roles.Add(role);

            await db.SaveChangesAsync();
        }

        return role.Id;
    }

    // The reference tables are empty in the migrated database, and more than one
    // test file needs the same city, type and category to be there.
    public async Task<int> EnsureCityAsync(string name)
    {
        await using var db = CreateContext();

        var country = await db.Countries.FirstOrDefaultAsync(row => row.IsoCode == "BA");

        if (country is null)
        {
            country = new Country { Name = "Bosnia and Herzegovina", IsoCode = "BA" };

            db.Countries.Add(country);
            await db.SaveChangesAsync();
        }

        var city = await db.Cities.FirstOrDefaultAsync(
            row => row.CountryId == country.Id && row.Name == name);

        if (city is null)
        {
            city = new City { Name = name, CountryId = country.Id };

            db.Cities.Add(city);
            await db.SaveChangesAsync();
        }

        return city.Id;
    }

    public async Task<int> EnsureAccommodationTypeAsync(string name)
    {
        await using var db = CreateContext();

        var type = await db.AccommodationTypes.FirstOrDefaultAsync(row => row.Name == name);

        if (type is null)
        {
            type = new AccommodationType { Name = name };

            db.AccommodationTypes.Add(type);
            await db.SaveChangesAsync();
        }

        return type.Id;
    }

    public async Task<int> EnsureAccommodationCategoryAsync(string name)
    {
        await using var db = CreateContext();

        var category = await db.AccommodationCategories.FirstOrDefaultAsync(
            row => row.Name == name);

        if (category is null)
        {
            category = new AccommodationCategory { Name = name };

            db.AccommodationCategories.Add(category);
            await db.SaveChangesAsync();
        }

        return category.Id;
    }

    public async Task<int> EnsureAmenityAsync(string name)
    {
        await using var db = CreateContext();

        var amenity = await db.Amenities.FirstOrDefaultAsync(row => row.Name == name);

        if (amenity is null)
        {
            amenity = new Amenity { Name = name };

            db.Amenities.Add(amenity);
            await db.SaveChangesAsync();
        }

        return amenity.Id;
    }

    private static User NewUser(string username, string email, string password) =>
        new()
        {
            FirstName = "Integration",
            LastName = "Tests",
            Username = username,
            Email = email,
            PasswordHash = PasswordHasher.Hash(password),
            CreatedAt = DateTime.UtcNow,
        };
}
