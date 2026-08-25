using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Notifications;

public interface INotificationService
{
    Task<PagedResult<NotificationResponse>> SearchAsync(
        NotificationSearchRequest search,
        CancellationToken cancellationToken);

    Task<UnreadCountResponse> UnreadAsync(CancellationToken cancellationToken);

    Task<NotificationResponse> MarkReadAsync(
        int notificationId,
        CancellationToken cancellationToken);

    Task<UnreadCountResponse> MarkAllReadAsync(CancellationToken cancellationToken);
}
