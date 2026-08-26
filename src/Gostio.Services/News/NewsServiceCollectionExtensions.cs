using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.News;

public static class NewsServiceCollectionExtensions
{
    public static IServiceCollection AddGostioNewsServices(this IServiceCollection services)
    {
        services.AddScoped<INewsService, NewsService>();

        return services;
    }
}
