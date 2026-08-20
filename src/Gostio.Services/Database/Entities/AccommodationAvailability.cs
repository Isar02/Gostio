namespace Gostio.Services.Database.Entities;

public class AccommodationAvailability
{
    public int Id { get; set; }

    public int AccommodationId { get; set; }

    public Accommodation Accommodation { get; set; } = null!;

    // Both dates are inclusive, the way a host reads a calendar, while a stay
    // covers the nights [CheckInDate, CheckOutDate).
    public DateOnly StartDate { get; set; }

    public DateOnly EndDate { get; set; }

    public bool IsAvailable { get; set; } = true;

    public decimal? PriceOverride { get; set; }
}
