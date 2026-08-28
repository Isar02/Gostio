using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Gostio.Services.Search;

public static class SearchServiceCollectionExtensions
{
    public static IServiceCollection AddGostioSearchServices(this IServiceCollection services)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddSingleton<SearchClock>();
        services.AddScoped<ISearchRecorder, SearchRecorder>();

        return services;
    }
}
