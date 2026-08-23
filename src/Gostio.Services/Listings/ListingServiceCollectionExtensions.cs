using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Listings;

public static class ListingServiceCollectionExtensions
{
    public static IServiceCollection AddGostioListingServices(this IServiceCollection services)
    {
        services.AddScoped<AccommodationAccess>();
        services.AddScoped<IAccommodationService, AccommodationService>();
        services.AddScoped<IAccommodationPhotoService, AccommodationPhotoService>();
        services.AddScoped<IAccommodationAmenityService, AccommodationAmenityService>();
        services.AddScoped<IAccommodationAvailabilityService, AccommodationAvailabilityService>();

        return services;
    }
}
