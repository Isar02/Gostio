namespace Gostio.Model.Responses;

public sealed class NotificationResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Type { get; init; }

    public int? ReservationId { get; init; }

    public required string Title { get; init; }

    public required string Body { get; init; }

    public required bool IsRead { get; init; }

    public DateTime? ReadAt { get; init; }

    public required DateTime CreatedAt { get; init; }
}
