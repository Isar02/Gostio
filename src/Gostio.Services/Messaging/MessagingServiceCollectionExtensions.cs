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
}
