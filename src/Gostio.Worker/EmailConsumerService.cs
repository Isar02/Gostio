using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;

namespace Gostio.Worker;

internal sealed class EmailConsumerService(
    RabbitMqConnection broker,
    IServiceScopeFactory scopes,
    RabbitMqSettings settings,
    ILogger<EmailConsumerService> logger)
    : QueueConsumerService<EmailMessage>(broker, scopes, settings, logger)
{
    protected override Task ActOnAsync(
        IServiceProvider services,
        EmailMessage message,
        CancellationToken cancellationToken) =>
        services.GetRequiredService<IEmailSender>().SendAsync(message, cancellationToken);
}
