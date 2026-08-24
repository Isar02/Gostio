namespace Gostio.Model.Requests;

public sealed class ExperienceSlotSearchRequest : PagedRequest
{
    public DateTime? From { get; set; }

    public DateTime? To { get; set; }

    public bool? IsActive { get; set; }
}
