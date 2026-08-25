namespace Gostio.Model.Responses;

public sealed class ConversationResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Type { get; init; }

    public int? ReservationId { get; init; }

    public string? ListingTitle { get; init; }

    public required IReadOnlyList<ConversationParticipantResponse> Participants { get; init; }

    public required DateTime CreatedAt { get; init; }

    // What an inbox is ordered by, worked out from the messages rather than
    // kept beside them.
    public required DateTime LastActivityAt { get; init; }
}
