namespace Gostio.Services.Database.Entities;

public class AccommodationAmenity
{
    public int AccommodationId { get; set; }

    public Accommodation Accommodation { get; set; } = null!;

    public int AmenityId { get; set; }

    public Amenity Amenity { get; set; } = null!;
}
