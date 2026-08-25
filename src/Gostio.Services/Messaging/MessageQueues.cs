using Gostio.Model.Messaging;
using Gostio.Services.Configuration;

namespace Gostio.Services.Messaging;

// Read by the publisher and the consumer both, so neither can drift.
public static class MessageQueues
{
    public static string For<TMessage>(RabbitMqSettings settings) =>
        For(typeof(TMessage), settings);

    public static string For(Type message, RabbitMqSettings settings) =>
        message == typeof(EmailMessage) ? settings.EmailQueue
        : message == typeof(NotificationMessage) ? settings.NotificationQueue
        : throw new InvalidOperationException($"No queue carries a {message.Name}.");

    public static IReadOnlyList<string> Declared(RabbitMqSettings settings) =>
        [settings.EmailQueue, settings.NotificationQueue];
}
