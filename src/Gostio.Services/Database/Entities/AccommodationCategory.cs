namespace Gostio.Services.Database.Entities;

// What a listing is good for: seaside, mountain, city break. Independent of
// AccommodationType, which describes the property itself.
public class AccommodationCategory : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
