namespace Gostio.Model.Requests;

public sealed class AccommodationAvailabilitySearchRequest : PagedRequest
{
    public DateOnly? From { get; set; }

    public DateOnly? To { get; set; }

    public bool? IsAvailable { get; set; }
}
