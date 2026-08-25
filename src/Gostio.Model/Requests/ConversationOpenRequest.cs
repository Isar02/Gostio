namespace Gostio.Model.Requests;

public sealed class ConversationOpenRequest
{
    public int? WithUserId { get; set; }

    public int? ReservationId { get; set; }
}
