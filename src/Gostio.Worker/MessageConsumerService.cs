using Gostio.Services.Configuration;

namespace Gostio.Worker;

/// <summary>
/// Background service that will consume messages published by the API through
/// RabbitMQ and carry out the asynchronous work: sending e-mail over SMTP and
/// processing notifications.
///
/// At this stage it only reports the configuration it resolved, which confirms
/// that the container is wired to the broker settings correctly. The RabbitMQ
/// connection and message handlers are added together with the messaging
/// module.
/// </summary>
public sealed class MessageConsumerService(
    ILogger<MessageConsumerService> logger,
    RabbitMqSettings rabbitMqSettings) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation(
            "Worker started. Broker {Host}:{Port}, queues '{EmailQueue}' and '{NotificationQueue}'.",
            rabbitMqSettings.Host,
            rabbitMqSettings.Port,
            rabbitMqSettings.EmailQueue,
            rabbitMqSettings.NotificationQueue);

        await Task.Delay(Timeout.Infinite, stoppingToken);
    }
}
