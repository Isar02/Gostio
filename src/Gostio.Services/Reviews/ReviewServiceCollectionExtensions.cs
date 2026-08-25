using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Reviews;

public static class ReviewServiceCollectionExtensions
{
    public static IServiceCollection AddGostioReviewServices(this IServiceCollection services)
    {
        services.AddScoped<IReviewService, ReviewService>();

        return services;
    }
}
