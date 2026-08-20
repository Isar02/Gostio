namespace Gostio.Services.Database.Entities;

public class ReservationStatus : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string Code { get; set; } = null!;

    public string? Description { get; set; }
}
