using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;

namespace Gostio.Worker;

internal sealed class NotificationConsumerService(
    RabbitMqConnection broker,
    IServiceScopeFactory scopes,
    RabbitMqSettings settings,
    ILogger<NotificationConsumerService> logger)
    : QueueConsumerService<NotificationMessage>(broker, scopes, settings, logger)
{
    protected override Task ActOnAsync(
        IServiceProvider services,
        NotificationMessage message,
        CancellationToken cancellationToken) =>
        services.GetRequiredService<INotificationWriter>()
            .WriteAsync(message, cancellationToken);
}
