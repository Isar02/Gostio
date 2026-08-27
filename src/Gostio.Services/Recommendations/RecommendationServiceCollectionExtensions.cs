using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Recommendations;

public static class RecommendationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioRecommendationServices(
        this IServiceCollection services)
    {
        services.AddScoped<AccommodationSignals>();
        services.AddScoped<ExperienceSignals>();
        services.AddScoped<IRecommendationService, RecommendationService>();

        return services;
    }
}
