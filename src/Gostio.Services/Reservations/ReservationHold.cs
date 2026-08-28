namespace Gostio.Services.Reservations;

public static class ReservationHold
{
    public static readonly TimeSpan Window = TimeSpan.FromHours(24);

    // A hold that outlives what it holds blocks the dates of a stay nobody paid
    // for, so it is shortened whenever the thing begins before the window ends.
    // Nothing is booked once it has begun, so there is no start behind `now`.
    public static DateTime Deadline(DateTime now, DateTime startsAt)
    {
        var deadline = now + Window;

        return startsAt < deadline ? startsAt : deadline;
    }
}
