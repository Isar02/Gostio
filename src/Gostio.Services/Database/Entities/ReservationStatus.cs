namespace Gostio.Services.Database.Entities;

// A closed set: every row is seeded and its id is a ReservationStatusCode. An
// administrator may reword Name and Description, because those are only shown,
// but Code is what a reader matches against the enum and never changes.
public class ReservationStatus : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string Code { get; set; } = null!;

    public string? Description { get; set; }
}
