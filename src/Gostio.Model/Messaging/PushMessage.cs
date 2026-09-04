using Gostio.Model.Enums;

namespace Gostio.Model.Messaging;

// The delivery of a notice rather than the notice itself: the row a
// NotificationMessage writes stays the record, and this is the tap on the
// phone that says it is there. Lost or delivered twice, nothing is lost.
public sealed class PushMessage
{
    public required int UserId { get; init; }

    public required NotificationType Type { get; init; }

    public int? ReservationId { get; init; }

    public required string Title { get; init; }

    public required string Body { get; init; }

    public static PushMessage Of(NotificationMessage notice) =>
        new()
        {
            UserId = notice.UserId,
            Type = notice.Type,
            ReservationId = notice.ReservationId,
            Title = notice.Title,
            Body = notice.Body,
        };
}
