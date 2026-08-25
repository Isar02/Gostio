using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Notifications;

public static class NotificationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioNotificationServices(
        this IServiceCollection services)
    {
        services.AddScoped<INotificationService, NotificationService>();

        return services;
    }
}
