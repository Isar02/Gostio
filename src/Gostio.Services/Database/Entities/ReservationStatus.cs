namespace Gostio.Services.Database.Entities;

// Four rows are seeded with the ids ReservationStatusCode names; an
// administrator may add others, which the state machine never assigns.
public class ReservationStatus : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string Code { get; set; } = null!;

    public string? Description { get; set; }
}
