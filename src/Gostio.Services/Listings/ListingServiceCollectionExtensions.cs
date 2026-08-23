using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Listings;

public static class ListingServiceCollectionExtensions
{
    public static IServiceCollection AddGostioListingServices(this IServiceCollection services)
    {
        services.AddScoped<IAccommodationService, AccommodationService>();

        return services;
    }
}
