using System.Text.Json;
using Gostio.Services.Configuration;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;

namespace Gostio.Services.Messaging;

internal sealed class RabbitMqPublisher(
    RabbitMqConnection broker,
    RabbitMqSettings settings,
    ILogger<RabbitMqPublisher> logger) : IMessagePublisher
{
    private const string Json = "application/json";

    public async Task PublishAsync<TMessage>(
        TMessage message,
        CancellationToken cancellationToken)
        where TMessage : class
    {
        var queue = MessageQueues.For<TMessage>(settings);
        var body = JsonSerializer.SerializeToUtf8Bytes(message, MessageJson.Options);

        // Persistent, durable and confirmed: a publish that returns is one the
        // broker has taken responsibility for.
        await broker.UseChannelAsync(
            channel => channel.BasicPublishAsync(
                exchange: string.Empty,
                routingKey: queue,
                mandatory: true,
                basicProperties: Describe<TMessage>(),
                body: body,
                cancellationToken).AsTask(),
            cancellationToken);

        logger.LogDebug("Published a {Message} to '{Queue}'.", typeof(TMessage).Name, queue);
    }

    private static BasicProperties Describe<TMessage>() => new()
    {
        ContentType = Json,
        DeliveryMode = DeliveryModes.Persistent,
        MessageId = Guid.NewGuid().ToString("N"),
        Type = typeof(TMessage).Name,
    };
}
