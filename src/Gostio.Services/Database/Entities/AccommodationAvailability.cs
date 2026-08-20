namespace Gostio.Services.Database.Entities;

// Exceptions to the calendar: a listing is bookable at its base price unless a
// row here blocks the dates or overrides the price. Both dates are inclusive,
// the way a host reads a calendar.
public class AccommodationAvailability
{
    public int Id { get; set; }

    public int AccommodationId { get; set; }

    public Accommodation Accommodation { get; set; } = null!;

    public DateOnly StartDate { get; set; }

    public DateOnly EndDate { get; set; }

    public bool IsAvailable { get; set; } = true;

    public decimal? PriceOverride { get; set; }
}
