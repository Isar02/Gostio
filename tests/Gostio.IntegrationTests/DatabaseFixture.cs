using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

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

        db.Users.Add(new User
        {
            FirstName = "Integration",
            LastName = "Tests",
            Username = SeededUsername,
            Email = "integration@example.com",
            PasswordHash = PasswordHasher.Hash(SeededPassword),
            CreatedAt = DateTime.UtcNow,
        });

        await db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        await using var db = CreateContext();

        await db.Database.EnsureDeletedAsync();
    }

    public GostioDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<GostioDbContext>()
            .UseSqlServer(connectionString)
            .Options);
}
