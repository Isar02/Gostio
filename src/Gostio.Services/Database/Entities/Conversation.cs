using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

public class Conversation
{
    public int Id { get; set; }

    public ConversationType Type { get; set; } = ConversationType.Direct;

    public int OpenedByUserId { get; set; }

    public User OpenedByUser { get; set; } = null!;

    public int? ReservationId { get; set; }

    public Reservation? Reservation { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<ConversationParticipant> Participants { get; set; } = [];

    public ICollection<Message> Messages { get; set; } = [];
}
