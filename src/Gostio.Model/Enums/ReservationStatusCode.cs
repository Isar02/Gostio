namespace Gostio.Model.Enums;

// These values are the seeded primary keys in ReservationStatuses, so they must
// never be renumbered.
public enum ReservationStatusCode
{
    Pending = 1,
    Confirmed = 2,
    Cancelled = 3,
    Completed = 4
}
