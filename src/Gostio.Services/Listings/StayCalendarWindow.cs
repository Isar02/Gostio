using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.Services.Listings;

// A calendar is a document over the window the caller names rather than a list,
// so it is bounded the way a report is instead of being paged.
public readonly record struct StayCalendarWindow(DateOnly From, DateOnly To)
{
    // The month on screen and the one after it. Counted in days answered rather
    // than days between, because both ends are inclusive.
    public const int MaximumDays = 62;

    public static StayCalendarWindow Require(StayCalendarRequest request)
    {
        var from = request.From
            ?? throw new ValidationException(
                nameof(StayCalendarRequest.From), "Say which day the calendar starts on.");

        var to = request.To
            ?? throw new ValidationException(
                nameof(StayCalendarRequest.To), "Say which day the calendar ends on.");

        if (to < from)
        {
            throw new ValidationException(
                nameof(StayCalendarRequest.To), "A calendar ends on or after the day it starts.");
        }

        if (to.DayNumber - from.DayNumber + 1 > MaximumDays)
        {
            throw new ValidationException(
                nameof(StayCalendarRequest.To),
                $"A calendar covers at most {MaximumDays} days.");
        }

        return new StayCalendarWindow(from, to);
    }

    // The closing day is yielded and then walked away from rather than stepped
    // past, because a step past the last day the calendar holds throws.
    public IEnumerable<DateOnly> Days()
    {
        for (var day = From; ; day = day.AddDays(1))
        {
            yield return day;

            if (day == To)
            {
                yield break;
            }
        }
    }
}
