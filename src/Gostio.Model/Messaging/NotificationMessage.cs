using Gostio.Model.Enums;

namespace Gostio.Model.Messaging;

public sealed class NotificationMessage
{
    public required int UserId { get; init; }

    public required NotificationType Type { get; init; }

    public int? ReservationId { get; init; }

    public required string Title { get; init; }

    public required string Body { get; init; }

    // When the event happened, not when the queue was read.
    public required DateTime CreatedAt { get; init; }
}
