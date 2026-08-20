namespace Gostio.Services.Database.Entities;

public class Favorite
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public int? AccommodationId { get; set; }

    public Accommodation? Accommodation { get; set; }

    public int? ExperienceId { get; set; }

    public Experience? Experience { get; set; }

    public DateTime CreatedAt { get; set; }
}
