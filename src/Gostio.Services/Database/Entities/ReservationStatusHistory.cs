namespace Gostio.Services.Database.Entities;

// The audit trail the proposal promises. A row is written for the creation too,
// with no previous status, so the trail is the whole life of a reservation.
public class ReservationStatusHistory
{
    public int Id { get; set; }

    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    public int? PreviousStatusId { get; set; }

    public ReservationStatus? PreviousStatus { get; set; }

    public int NewStatusId { get; set; }

    public ReservationStatus NewStatus { get; set; } = null!;

    // Null only when nobody acted: an expired hold swept up by the job. A
    // cancellation or a reschedule a host started names that host, even when it
    // moves reservations the host never looked at.
    public int? ChangedByUserId { get; set; }

    public User? ChangedByUser { get; set; }

    public DateTime ChangedAt { get; set; }

    // What separates a cancellation from a rejection, since both land on
    // Cancelled. Required for those two by the reservation service, not by a
    // constraint, which would have to name a status id in the schema.
    public string? Reason { get; set; }
}
