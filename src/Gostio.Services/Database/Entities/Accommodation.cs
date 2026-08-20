namespace Gostio.Services.Database.Entities;

public class Accommodation
{
    public int Id { get; set; }

    public int HostId { get; set; }

    public User Host { get; set; } = null!;

    public string Title { get; set; } = null!;

    public string Description { get; set; } = null!;

    public int AccommodationTypeId { get; set; }

    public AccommodationType AccommodationType { get; set; } = null!;

    public int AccommodationCategoryId { get; set; }

    public AccommodationCategory AccommodationCategory { get; set; } = null!;

    public int CityId { get; set; }

    public City City { get; set; } = null!;

    public string Address { get; set; } = null!;

    public decimal Latitude { get; set; }

    public decimal Longitude { get; set; }

    public int MaxGuests { get; set; }

    public int Bedrooms { get; set; }

    public int Bathrooms { get; set; }

    public decimal PricePerNight { get; set; }

    // Charged once per reservation, on top of the nightly price.
    public decimal CleaningFee { get; set; }

    // Cleared to take the listing off the market, so reservations and reviews
    // keep pointing at it.
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }

    public ICollection<AccommodationPhoto> Photos { get; set; } = [];

    public ICollection<AccommodationAmenity> Amenities { get; set; } = [];

    public ICollection<AccommodationAvailability> Availability { get; set; } = [];
}
