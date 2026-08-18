using Gostio.Services.Configuration;

namespace Gostio.Worker;

// Scaffolding for the messaging phase: reports the resolved broker settings and idles.
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
