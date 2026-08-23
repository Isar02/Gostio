using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Lookups;

public static class LookupServiceCollectionExtensions
{
    public static IServiceCollection AddGostioLookupServices(this IServiceCollection services)
    {
        services.AddScoped<IAccommodationTypeService, AccommodationTypeService>();
        services.AddScoped<IAccommodationCategoryService, AccommodationCategoryService>();
        services.AddScoped<IExperienceCategoryService, ExperienceCategoryService>();
        services.AddScoped<IAmenityService, AmenityService>();
        services.AddScoped<IRoleService, RoleService>();

        return services;
    }
}
