using Microsoft.Extensions.Logging;

namespace Gostio.Services.Messaging;

// A notice never fails what raised it: an unreachable broker is the operator's
// problem, not the caller's, so it is written down rather than handed back.
internal sealed class Notices(IMessagePublisher publisher, ILogger<Notices> logger) : INotices
{
    public async Task<bool> SendAsync<TMessage>(
        TMessage message,
        CancellationToken cancellationToken)
        where TMessage : class
    {
        try
        {
            await publisher.PublishAsync(message, cancellationToken);

            return true;
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(
                failure,
                "{Message} never reached the broker. What it carried was not delivered.",
                typeof(TMessage).Name);

            return false;
        }
    }
}
