namespace Gostio.Model.Responses;

public sealed class MessageResponse : IIdentified
{
    public required int Id { get; init; }

    public required int ConversationId { get; init; }

    public required int SenderUserId { get; init; }

    public required string SenderName { get; init; }

    public required string Body { get; init; }

    public required DateTime SentAt { get; init; }
}
