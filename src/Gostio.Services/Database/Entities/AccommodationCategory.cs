namespace Gostio.Services.Database.Entities;

public class AccommodationCategory : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
