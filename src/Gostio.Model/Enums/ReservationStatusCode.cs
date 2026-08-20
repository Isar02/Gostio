namespace Gostio.Model.Enums;

// The values are the primary keys seeded into ReservationStatuses, so they must
// never be renumbered. The table stores what a status is called; this decides
// what the code does with it, and only these four exist.
public enum ReservationStatusCode
{
    Pending = 1,
    Confirmed = 2,
    Cancelled = 3,
    Completed = 4
}
