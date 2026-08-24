using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database;

public static class ReservationQueries
{
    // The one definition of an active reservation. Capacity counts and overlap
    // queries filter on it and never restate it: one forgotten expiry test
    // leaves an abandoned hold blocking a place for good.
    public static Expression<Func<Reservation, bool>> IsActive(DateTime now) =>
        reservation =>
            reservation.ReservationStatusId == (int)ReservationStatusCode.Confirmed
            || (reservation.ReservationStatusId == (int)ReservationStatusCode.Pending
                && reservation.ExpiresAt > now);

    // The other side of the boundary above, kept beside it so that a change to
    // ExpiresAt cannot move one without the other.
    public static Expression<Func<Reservation, bool>> IsALapsedHold(DateTime now) =>
        reservation =>
            reservation.ReservationStatusId == (int)ReservationStatusCode.Pending
            && reservation.ExpiresAt <= now;
}
