using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Gostio.Services.Notifications;

public static class NotificationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioNotificationServices(
        this IServiceCollection services)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IDeviceTokenService, DeviceTokenService>();

        return services;
    }
}
