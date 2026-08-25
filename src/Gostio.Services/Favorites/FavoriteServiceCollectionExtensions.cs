using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Favorites;

public static class FavoriteServiceCollectionExtensions
{
    public static IServiceCollection AddGostioFavoriteServices(this IServiceCollection services)
    {
        services.AddScoped<IFavoriteService, FavoriteService>();
        services.AddScoped<IAccommodationFavoriteService, AccommodationFavoriteService>();
        services.AddScoped<IExperienceFavoriteService, ExperienceFavoriteService>();

        return services;
    }
}
