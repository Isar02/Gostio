namespace Gostio.Services.Database.Entities;

public class ConversationParticipant
{
    public int ConversationId { get; set; }

    public Conversation Conversation { get; set; } = null!;

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public DateTime JoinedAt { get; set; }

    // The only record of what a participant has seen; a message carries no read
    // flag of its own.
    public DateTime? LastReadAt { get; set; }
}
