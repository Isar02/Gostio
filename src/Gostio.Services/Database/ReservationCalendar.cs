using System.Linq.Expressions;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reservations;

namespace Gostio.Services.Database;

// The days a booking takes up, in the two units the model measures them in. A
// stay covers the nights [CheckInDate, CheckOutDate), so the day it ends on is
// not one of them. A term covers the one local day its slot starts on, and that
// slot stores a moment rather than a day: reading the moment's UTC date would
// put an early enough term on the day before.
public static class ReservationCalendar
{
    public static Expression<Func<Reservation, bool>> OccupiesOnOrAfter(DateOnly day)
    {
        var dayBegins = StayTimes.StartOfDay(day);

        return reservation =>
            reservation.CheckOutDate > day
            || (reservation.ExperienceSlot != null
                && reservation.ExperienceSlot.StartTime >= dayBegins);
    }

    public static Expression<Func<Reservation, bool>> OccupiesOnOrBefore(DateOnly day)
    {
        // There is no day after the last representable one, and the bound it
        // would carry is the end of time, which every term is already under.
        var dayEnds = day == DateOnly.MaxValue
            ? DateTime.MaxValue
            : StayTimes.StartOfDay(day.AddDays(1));

        return reservation =>
            reservation.CheckInDate <= day
            || (reservation.ExperienceSlot != null
                && reservation.ExperienceSlot.StartTime < dayEnds);
    }

    // A term is attended rather than arrived at, and takes up one day either
    // way, so these answer for stays alone; a window is what asks after a term.
    public static Expression<Func<Reservation, bool>> ArrivesOn(DateOnly day) =>
        reservation => reservation.CheckInDate == day;

    public static Expression<Func<Reservation, bool>> DepartsOn(DateOnly day) =>
        reservation => reservation.CheckOutDate == day;
}
