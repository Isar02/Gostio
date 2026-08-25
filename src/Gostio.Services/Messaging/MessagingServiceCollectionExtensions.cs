using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Messaging;

public static class MessagingServiceCollectionExtensions
{
    public static IServiceCollection AddGostioMessaging(this IServiceCollection services)
    {
        services.AddSingleton<RabbitMqConnection>();
        services.AddSingleton<IMessagePublisher, RabbitMqPublisher>();

        return services;
    }

    public static IServiceCollection AddGostioMessageConsumers(this IServiceCollection services)
    {
        services.AddGostioMessaging();

        services.AddSingleton<IEmailSender, SmtpEmailSender>();
        services.AddScoped<INotificationWriter, NotificationWriter>();

        return services;
    }
}
