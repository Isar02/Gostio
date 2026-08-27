using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Search;

public static class SearchServiceCollectionExtensions
{
    public static IServiceCollection AddGostioSearchServices(this IServiceCollection services)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<SearchClock>();
        services.AddScoped<ISearchRecorder, SearchRecorder>();

        return services;
    }
}
