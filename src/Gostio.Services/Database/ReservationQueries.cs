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

    public static Expression<Func<Reservation, bool>> IsNotActive(DateTime now) =>
        Negated(IsActive(now));

    // The other side of the boundary above, kept beside it so that a change to
    // ExpiresAt cannot move one without the other.
    public static Expression<Func<Reservation, bool>> IsALapsedHold(DateTime now) =>
        reservation =>
            reservation.ReservationStatusId == (int)ReservationStatusCode.Pending
            && reservation.ExpiresAt <= now;

    public static Expression<Func<Reservation, bool>> IsHostedBy(int hostId) =>
        reservation =>
            (reservation.Accommodation != null && reservation.Accommodation.HostId == hostId)
            || (reservation.ExperienceSlot != null
                && reservation.ExperienceSlot.Experience.HostId == hostId);

    // Not composed from the predicate above: an OR built out of two lambdas
    // costs every read of a single row a subquery over the whole table.
    public static Expression<Func<Reservation, bool>> IsReachableBy(int userId) =>
        reservation =>
            reservation.UserId == userId
            || (reservation.Accommodation != null && reservation.Accommodation.HostId == userId)
            || (reservation.ExperienceSlot != null
                && reservation.ExperienceSlot.Experience.HostId == userId);

    private static Expression<Func<Reservation, bool>> Negated(
        Expression<Func<Reservation, bool>> predicate) =>
        Expression.Lambda<Func<Reservation, bool>>(
            Expression.Not(predicate.Body), predicate.Parameters);
}
