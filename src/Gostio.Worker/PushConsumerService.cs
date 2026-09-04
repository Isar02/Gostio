using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;

namespace Gostio.Worker;

// A queue of its own rather than a second reader on the notifications one: a
// push that cannot be delivered retries and eventually dies here, and the row
// it belongs to was written by a consumer that never saw the failure.
internal sealed class PushConsumerService(
    RabbitMqConnection broker,
    IServiceScopeFactory scopes,
    RabbitMqSettings settings,
    ILogger<PushConsumerService> logger)
    : QueueConsumerService<PushMessage>(broker, scopes, settings, logger)
{
    protected override Task ActOnAsync(
        IServiceProvider services,
        PushMessage message,
        CancellationToken cancellationToken) =>
        services.GetRequiredService<IPushDispatcher>().DeliverAsync(message, cancellationToken);
}
