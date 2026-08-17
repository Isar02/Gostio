namespace Gostio.Services.Database.Entities;

/// <summary>
/// What a listing is good for: seaside, mountain, city break. Independent of
/// <see cref="AccommodationType"/>, which describes the property itself.
/// </summary>
public class AccommodationCategory : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
