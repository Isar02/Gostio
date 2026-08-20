namespace Gostio.Services.Database.Entities;

public class ReservationStatusHistory
{
    public int Id { get; set; }

    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    public int? PreviousStatusId { get; set; }

    public ReservationStatus? PreviousStatus { get; set; }

    public int NewStatusId { get; set; }

    public ReservationStatus NewStatus { get; set; } = null!;

    public int? ChangedByUserId { get; set; }

    public User? ChangedByUser { get; set; }

    public DateTime ChangedAt { get; set; }

    public string? Reason { get; set; }
}
