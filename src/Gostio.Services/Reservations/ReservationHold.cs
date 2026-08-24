namespace Gostio.Services.Reservations;

public static class ReservationHold
{
    public static readonly TimeSpan Window = TimeSpan.FromHours(24);

    // A hold that outlives what it holds blocks the dates of a stay nobody paid
    // for. It is shortened only when the thing starts sooner than the window
    // ends and has not started already, which a same-day booking has.
    public static DateTime Deadline(DateTime now, DateTime startsAt)
    {
        var deadline = now + Window;

        return startsAt > now && startsAt < deadline ? startsAt : deadline;
    }
}
