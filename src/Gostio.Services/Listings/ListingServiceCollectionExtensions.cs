using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Gostio.Services.Listings;

public static class ListingServiceCollectionExtensions
{
    public static IServiceCollection AddGostioListingServices(this IServiceCollection services)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddScoped<AccommodationAccess>();
        services.AddScoped<ExperienceAccess>();
        services.AddScoped<IAccommodationService, AccommodationService>();
        services.AddScoped<IAccommodationPhotoService, AccommodationPhotoService>();
        services.AddScoped<IAccommodationAmenityService, AccommodationAmenityService>();
        services.AddScoped<IAccommodationAvailabilityService, AccommodationAvailabilityService>();
        services.AddScoped<IStayCalendarService, StayCalendarService>();
        services.AddScoped<IExperienceService, ExperienceService>();
        services.AddScoped<IExperiencePhotoService, ExperiencePhotoService>();
        services.AddScoped<IExperienceSlotService, ExperienceSlotService>();

        return services;
    }
}
