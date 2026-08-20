namespace Gostio.Services.Database.Entities;

public class ExperienceSlot
{
    public int Id { get; set; }

    public int ExperienceId { get; set; }

    public Experience Experience { get; set; } = null!;

    public DateTime StartTime { get; set; }

    // Copied from the experience when the slot is created and owned by the slot
    // from then on, so editing the experience cannot move a booked term.
    public int DurationMinutes { get; set; }

    public int Capacity { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
}
