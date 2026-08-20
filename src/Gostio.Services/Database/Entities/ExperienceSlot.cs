namespace Gostio.Services.Database.Entities;

public class ExperienceSlot
{
    public int Id { get; set; }

    public int ExperienceId { get; set; }

    public Experience Experience { get; set; } = null!;

    public DateTime StartTime { get; set; }

    // Copied from the experience when the slot is created and owned here after
    // that, so editing the experience never moves the end of a booked term. With
    // the start time, this is the whole term: a reservation snapshots neither.
    public int DurationMinutes { get; set; }

    // Total places, never the remaining ones. Free places are counted from the
    // active reservations inside the transaction that books one.
    public int Capacity { get; set; }

    // Cleared to cancel the term, so its reservations keep pointing at it.
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
}
