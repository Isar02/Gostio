namespace Gostio.Services.Database.Entities;

public class Country : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    // ISO 3166-1 alpha-2.
    public string IsoCode { get; set; } = null!;

    public ICollection<City> Cities { get; set; } = [];
}
