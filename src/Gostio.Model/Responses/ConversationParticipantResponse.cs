namespace Gostio.Model.Responses;

public sealed class ConversationParticipantResponse
{
    public required int UserId { get; init; }

    public required string Username { get; init; }

    public required string Name { get; init; }

    public required DateTime JoinedAt { get; init; }

    public DateTime? LastReadAt { get; init; }
}
