using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.HostVerification;

public static class HostVerificationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioHostVerificationServices(
        this IServiceCollection services)
    {
        services.AddScoped<IHostVerificationService, HostVerificationService>();

        return services;
    }
}
