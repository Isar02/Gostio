using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

// No participant filter for the caller: they are in every thread this answers
// with, so naming themselves would narrow nothing.
public sealed class ConversationSearchRequest : PagedRequest
{
    public ConversationType? Type { get; set; }

    public int? ReservationId { get; set; }

    public int? WithUserId { get; set; }
}
