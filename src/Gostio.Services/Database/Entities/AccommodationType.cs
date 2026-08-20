namespace Gostio.Services.Database.Entities;

public class AccommodationType : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
