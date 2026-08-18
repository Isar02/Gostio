namespace Gostio.Services.Database.Entities;

// The physical kind of a listing: apartment, house, room, villa.
public class AccommodationType : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
