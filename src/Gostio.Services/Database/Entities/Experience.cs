namespace Gostio.Services.Database.Entities;

public class Experience
{
    public int Id { get; set; }

    public int HostId { get; set; }

    public User Host { get; set; } = null!;

    public string Title { get; set; } = null!;

    public string Description { get; set; } = null!;

    public int ExperienceCategoryId { get; set; }

    public ExperienceCategory ExperienceCategory { get; set; } = null!;

    public int CityId { get; set; }

    public City City { get; set; } = null!;

    public string MeetingPoint { get; set; } = null!;

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    // A slot carries only its start, so the end of a term is derived from this.
    public int DurationMinutes { get; set; }

    public decimal PricePerPerson { get; set; }

    // Cleared to take the experience off the market, so reservations and reviews
    // keep pointing at it.
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }

    public ICollection<ExperiencePhoto> Photos { get; set; } = [];

    public ICollection<ExperienceSlot> Slots { get; set; } = [];
}
