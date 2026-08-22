namespace Gostio.Services.Database.Entities;

public class Message
{
    public int Id { get; set; }

    public int ConversationId { get; set; }

    public Conversation Conversation { get; set; } = null!;

    public int SenderUserId { get; set; }

    public User SenderUser { get; set; } = null!;

    public string Body { get; set; } = null!;

    public DateTime SentAt { get; set; }
}
