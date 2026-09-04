using Gostio.Model.Messaging;

namespace Gostio.Services.Messaging;

public enum PushDelivery
{
    Delivered = 1,
    Unregistered = 2
}

// Behind this the worker knows about a queue and not about Firebase.
public interface IPushSender
{
    Task<PushDelivery> SendAsync(
        string token,
        PushMessage message,
        CancellationToken cancellationToken);
}
