namespace Gostio.Services.Database.Entities;

// The reservation names both the author and what was reviewed, so neither is
// repeated here. One review per reservation, and only once it is completed.
public class Review
{
    public int Id { get; set; }

    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    public int Rating { get; set; }

    public string? Comment { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }
}
