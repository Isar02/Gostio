namespace Gostio.Model.Requests;

public sealed class AccommodationAvailabilitySearchRequest : PagedRequest
{
    // A range is wanted when it touches the window, not when it sits inside it:
    // the block that closes a stay usually starts before the dates asked about.
    public DateOnly? From { get; set; }

    public DateOnly? To { get; set; }

    public bool? IsAvailable { get; set; }
}
