using Gostio.Model.Messaging;

namespace Gostio.Services.Messaging;

public interface INotificationWriter
{
    Task WriteAsync(NotificationMessage message, CancellationToken cancellationToken);
}
