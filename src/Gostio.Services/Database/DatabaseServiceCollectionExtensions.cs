using Gostio.Services.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Database;

public static class DatabaseServiceCollectionExtensions
{
    public static IServiceCollection AddGostioDatabase(
        this IServiceCollection services,
        DatabaseSettings database)
    {
        services.AddDbContext<GostioDbContext>(options =>
            options.UseSqlServer(database.ConnectionString));

        return services;
    }
}
