using System.Text.Json;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace Gostio.Worker;

internal abstract class QueueConsumerService<TMessage>(
    RabbitMqConnection broker,
    IServiceScopeFactory scopes,
    RabbitMqSettings settings,
    ILogger logger) : BackgroundService
    where TMessage : class
{
    private const ushort OneAtATime = 1;

    protected abstract Task ActOnAsync(
        IServiceProvider services,
        TMessage message,
        CancellationToken cancellationToken);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var queue = MessageQueues.For<TMessage>(settings);

        try
        {
            for (var attempt = 1; ; attempt++)
            {
                await OnceAsync(queue, stoppingToken);
                await Task.Delay(RetryBackoff.Reopening(attempt), stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("Stopped listening on '{Queue}'.", queue);
        }
    }

    private async Task OnceAsync(string queue, CancellationToken stoppingToken)
    {
        try
        {
            await ListenAsync(queue, stoppingToken);
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(failure, "The listener on '{Queue}' failed.", queue);
        }
    }

    // Returns when the channel closes, because reopening is this loop's business
    // and not the client's: a channel the broker closed is never recovered.
    private async Task ListenAsync(string queue, CancellationToken stoppingToken)
    {
        var closed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        await using var channel = await broker.OpenChannelAsync(stoppingToken);

        channel.ChannelShutdownAsync += (_, shutdown) =>
        {
            logger.LogWarning(
                "The channel on '{Queue}' closed: {Reason}. Opening another.",
                queue,
                shutdown.ReplyText);

            closed.TrySetResult();

            return Task.CompletedTask;
        };

        // One message at a time: a handler waiting out a retry is holding this
        // consumer, and prefetching more would only age behind it.
        await channel.BasicQosAsync(
            prefetchSize: 0, prefetchCount: OneAtATime, global: false, stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(channel);

        consumer.ReceivedAsync += (_, delivery) => HandleAsync(channel, delivery, stoppingToken);

        await channel.BasicConsumeAsync(queue, autoAck: false, consumer, stoppingToken);

        logger.LogInformation("Listening on '{Queue}'.", queue);

        await using var stopping = stoppingToken.Register(() => closed.TrySetResult());

        await closed.Task;

        stoppingToken.ThrowIfCancellationRequested();
    }

    private async Task HandleAsync(
        IChannel channel,
        BasicDeliverEventArgs delivery,
        CancellationToken stoppingToken)
    {
        try
        {
            var message = Read(delivery);

            if (message is null)
            {
                await channel.BasicRejectAsync(
                    delivery.DeliveryTag, requeue: false, stoppingToken);

                return;
            }

            await DeliverAsync(channel, delivery, message, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Unacknowledged, so the broker hands it to whoever listens next.
            return;
        }
        catch (Exception failure)
        {
            logger.LogError(
                failure, "The delivery {Tag} could not be answered.", delivery.DeliveryTag);
        }
    }

    private async Task DeliverAsync(
        IChannel channel,
        BasicDeliverEventArgs delivery,
        TMessage message,
        CancellationToken stoppingToken)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();

                await ActOnAsync(scope.ServiceProvider, message, stoppingToken);
                await channel.BasicAckAsync(delivery.DeliveryTag, multiple: false, stoppingToken);

                return;
            }
            catch (PermanentMessageFailure failure)
            {
                logger.LogError(
                    failure,
                    "{Message} cannot be delivered as this deployment stands, so it was dropped.",
                    typeof(TMessage).Name);

                await channel.BasicRejectAsync(
                    delivery.DeliveryTag, requeue: false, stoppingToken);

                return;
            }
            catch (Exception failure) when (failure is not OperationCanceledException
                && attempt < RetryBackoff.Attempts)
            {
                var wait = RetryBackoff.After(attempt);

                logger.LogWarning(
                    failure,
                    "Attempt {Attempt} at {Message} failed. Trying again in {Wait}.",
                    attempt,
                    typeof(TMessage).Name,
                    wait);

                await Task.Delay(wait, stoppingToken);
            }
            catch (Exception failure) when (failure is not OperationCanceledException)
            {
                logger.LogError(
                    failure,
                    "{Message} failed {Attempts} times and was dropped. What it carried was "
                        + "never delivered.",
                    typeof(TMessage).Name,
                    RetryBackoff.Attempts);

                await channel.BasicRejectAsync(
                    delivery.DeliveryTag, requeue: false, stoppingToken);

                return;
            }
        }
    }

    private TMessage? Read(BasicDeliverEventArgs delivery)
    {
        try
        {
            return JsonSerializer.Deserialize<TMessage>(delivery.Body.Span, MessageJson.Options)
                ?? throw new JsonException("The body was the literal null.");
        }
        catch (JsonException failure)
        {
            logger.LogError(
                failure,
                "The delivery {Tag} did not carry {Message} and was dropped.",
                delivery.DeliveryTag,
                typeof(TMessage).Name);

            return null;
        }
    }
}
