using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Favorites;
using Gostio.Services.Listings;
using Gostio.Services.Lookups;
using Gostio.Services.Messaging;
using Gostio.Services.Notifications;
using Gostio.Services.Payments;
using Gostio.Services.Reservations;
using Gostio.Services.Reviews;
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

    public StripeSettings Stripe { get; } = new()
    {
        PublishableKey = "pk_test_integration",
        SecretKey = "sk_test_integration",
        WebhookSecret = "whsec_integration",
        Currency = "eur",
    };

    public WorkerSettings Worker { get; } = new()
    {
        ReservationSweepSeconds = 60,
        ReservationSweepBatch = 200,
        RefundSweepSeconds = 120,
        RefundSweepBatch = 50,
    };

    public ApiSettings Api { get; } = new()
    {
        BaseUrl = "http://localhost:5000",
        HttpPort = 5000,
    };

    public RabbitMqSettings Broker { get; } = new()
    {
        Host = "localhost",
        Port = 5672,
        Username = "integration",
        Password = "integration",
        VirtualHost = "/",
        EmailQueue = "gostio.email.tests",
        NotificationQueue = "gostio.notifications.tests",
    };

    public SmtpSettings Smtp { get; } = new()
    {
        Host = "localhost",
        Port = 587,
        Username = "",
        Password = "",
        UseSsl = false,
        FromEmail = "integration@example.com",
        FromName = "Gostio",
    };

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
        params IInterceptor[] interceptors) =>
        BuildServices(caller, gateway: null, interceptors);

    public ServiceProvider BuildServices(
        ICurrentUser? caller,
        IPaymentGateway? gateway,
        params IInterceptor[] interceptors) =>
        BuildServices(caller, gateway, new CapturedNotices(), interceptors);

    // The broker takes no part in a test; what would have been published is
    // kept in a list, or handed to whatever the test passed instead.
    public ServiceProvider BuildServices(
        ICurrentUser? caller,
        IPaymentGateway? gateway,
        INotices notices,
        params IInterceptor[] interceptors)
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddScoped(_ => CreateContext(interceptors));
        services.AddScoped(_ => caller ?? new AnonymousUser());
        services.AddSingleton(Stripe);
        services.AddSingleton(Worker);
        services.AddSingleton(notices);
        services.AddGostioLookupServices();
        services.AddGostioListingServices();
        services.AddGostioUserServices();
        services.AddGostioReservationServices();
        services.AddGostioPaymentServices();
        services.AddGostioReviewServices();
        services.AddGostioFavoriteServices();
        services.AddGostioNotificationServices();

        services.AddScoped(_ => gateway ?? new FakePaymentGateway());

        return services.BuildServiceProvider();
    }

    // The worker's composition rather than the API's: no caller, and a batch
    // the test picks.
    public ServiceProvider BuildSweep(int batch, params IInterceptor[] interceptors) =>
        BuildSweep(batch, new CapturedNotices(), interceptors);

    public ServiceProvider BuildSweep(
        int batch,
        INotices notices,
        params IInterceptor[] interceptors)
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddScoped(_ => CreateContext(interceptors));
        services.AddSingleton(BatchOf(batch));
        services.AddSingleton(notices);
        services.AddGostioReservationSweep();

        return services.BuildServiceProvider();
    }

    public ServiceProvider BuildRefundSweep(
        IPaymentGateway gateway,
        int batch = 50,
        INotices? notices = null)
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddScoped(_ => CreateContext());
        services.AddSingleton(Stripe);
        services.AddSingleton(BatchOf(batch));
        services.AddSingleton<INotices>(notices ?? new CapturedNotices());
        services.AddGostioReservationSweep();
        services.AddGostioRefundSweep();
        services.AddScoped(_ => gateway);

        return services.BuildServiceProvider();
    }

    private WorkerSettings BatchOf(int batch) => new()
    {
        ReservationSweepSeconds = Worker.ReservationSweepSeconds,
        ReservationSweepBatch = batch,
        RefundSweepSeconds = Worker.RefundSweepSeconds,
        RefundSweepBatch = batch,
    };

    // The worker's composition for the queues: what a message asks for once it
    // has been read, with nothing here reaching a broker.
    public ServiceProvider BuildConsumers()
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddScoped(_ => CreateContext());
        services.AddSingleton(Broker);
        services.AddSingleton(Smtp);
        services.AddGostioMessageConsumers();

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

    public async Task<int> EnsureExperienceCategoryAsync(string name)
    {
        await using var db = CreateContext();

        var category = await db.ExperienceCategories.FirstOrDefaultAsync(row => row.Name == name);

        if (category is null)
        {
            category = new ExperienceCategory { Name = name };

            db.ExperienceCategories.Add(category);
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
