using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database;

// The one definition of an active reservation. The capacity count and the
// overlap query both filter on it and never restate the condition themselves,
// because a single forgotten expiry test leaves an abandoned hold blocking a
// place for good.
public static class ReservationQueries
{
    // An expression rather than a property on the entity, so the condition
    // reaches SQL instead of filtering rows already loaded. It is deliberately
    // not a global query filter either: a guest still has to see the
    // reservations they cancelled.
    //
    // A background job turns expired holds into cancellations for the sake of
    // history and the screens, but this cannot wait for it: between the deadline
    // and the next pass the row is still pending.
    public static Expression<Func<Reservation, bool>> IsActive(DateTime now) =>
        reservation =>
            reservation.ReservationStatusId == (int)ReservationStatusCode.Confirmed
            || (reservation.ReservationStatusId == (int)ReservationStatusCode.Pending
                && reservation.ExpiresAt > now);
}
