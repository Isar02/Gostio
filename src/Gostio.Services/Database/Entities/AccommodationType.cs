namespace Gostio.Services.Database.Entities;

/// <summary>The physical kind of a listing: apartment, house, room, villa.</summary>
public class AccommodationType : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
