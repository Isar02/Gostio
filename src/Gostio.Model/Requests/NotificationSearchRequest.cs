using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

// No user filter: the caller is the only person it can be about.
public sealed class NotificationSearchRequest : PagedRequest
{
    public bool? IsRead { get; set; }

    public NotificationType? Type { get; set; }
}
