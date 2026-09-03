namespace Gostio.Model.Responses;

public sealed class ConversationParticipantResponse
{
    public required int UserId { get; init; }

    public required string Username { get; init; }

    public required string Name { get; init; }

    // Whether the account has a picture. The bytes come from a route of
    // their own; no reply carries them.
    public required bool HasProfileImage { get; init; }

    public required DateTime JoinedAt { get; init; }

    public DateTime? LastReadAt { get; init; }
}
