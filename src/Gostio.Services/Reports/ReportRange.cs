using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.Services.Reports;

// A report is a document rather than a list, so nothing pages it and the range
// is what bounds the rows instead.
public readonly record struct ReportRange(DateOnly From, DateOnly To)
{
    public const int MaximumMonths = 24;

    public DateTime FromUtc => From.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);

    // Half open and a whole day past the last one asked for, so every moment of
    // the closing date belongs to the report rather than only its midnight. It
    // is also why a range may not close on the last date the calendar holds:
    // there is no day after it to put the bound on.
    public DateTime UntilUtc => To.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);

    public static ReportRange Require(ReportRangeRequest request)
    {
        var from = request.From
            ?? throw new ValidationException(
                nameof(ReportRangeRequest.From), "Say which date the report starts on.");

        var to = request.To
            ?? throw new ValidationException(
                nameof(ReportRangeRequest.To), "Say which date the report ends on.");

        if (to < from)
        {
            throw new ValidationException(
                nameof(ReportRangeRequest.To), "A report cannot end before it starts.");
        }

        if (to == DateOnly.MaxValue)
        {
            throw new ValidationException(
                nameof(ReportRangeRequest.To), "A report cannot end on the last date there is.");
        }

        if (MonthsBetween(from, to) > MaximumMonths)
        {
            throw new ValidationException(
                nameof(ReportRangeRequest.To),
                $"A report covers at most {MaximumMonths} months.");
        }

        return new ReportRange(from, to);
    }

    // Every month the range touches, including the ones nothing happened in: a
    // printed document with a gap where a month should be reads as broken. The
    // closing month is yielded and then walked away from rather than stepped
    // past, because a step past the last month the calendar holds throws.
    public IEnumerable<(int Year, int Month)> Months()
    {
        var last = new DateOnly(To.Year, To.Month, 1);
        var month = new DateOnly(From.Year, From.Month, 1);

        while (month <= last)
        {
            yield return (month.Year, month.Month);

            if (month == last)
            {
                yield break;
            }

            month = month.AddMonths(1);
        }
    }

    private static int MonthsBetween(DateOnly from, DateOnly to) =>
        ((to.Year - from.Year) * 12) + to.Month - from.Month + 1;
}
