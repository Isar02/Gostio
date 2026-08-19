namespace Gostio.Services.Database.Entities;

public class ExperienceSlot
{
    public int Id { get; set; }

    public int ExperienceId { get; set; }

    public Experience Experience { get; set; } = null!;

    public DateTime StartTime { get; set; }

    // Total places, never the remaining ones. Free places are counted from the
    // active reservations inside the transaction that books one.
    public int Capacity { get; set; }

    // Cleared to cancel the term, so its reservations keep pointing at it.
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
}
