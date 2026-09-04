using Gostio.Model.Messaging;

namespace Gostio.Services.Messaging;

public interface IPushDispatcher
{
    Task DeliverAsync(PushMessage message, CancellationToken cancellationToken);
}
