using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Reports;

namespace Gostio.Tests.Reports;

public class ReportRangeTests
{
    [Fact]
    public void ARangeWithoutAStartIsRefusedUnderItsOwnField()
    {
        var refused = Assert.Throws<ValidationException>(
            () => ReportRange.Require(Asked(from: null, to: new DateOnly(2026, 1, 31))));

        Assert.Contains(nameof(ReportRangeRequest.From), refused.Errors.Keys);
    }

    [Fact]
    public void ARangeWithoutAnEndIsRefusedUnderItsOwnField()
    {
        var refused = Assert.Throws<ValidationException>(
            () => ReportRange.Require(Asked(new DateOnly(2026, 1, 1), to: null)));

        Assert.Contains(nameof(ReportRangeRequest.To), refused.Errors.Keys);
    }

    [Fact]
    public void ARangeThatEndsBeforeItStartsIsRefused()
    {
        var refused = Assert.Throws<ValidationException>(() => ReportRange.Require(
            Asked(new DateOnly(2026, 3, 1), new DateOnly(2026, 2, 28))));

        Assert.Contains(nameof(ReportRangeRequest.To), refused.Errors.Keys);
    }

    // The bound is what stands in for a page size: nothing pages a document, so
    // the months it may cover are what keep its rows countable.
    [Theory]
    [InlineData(24, true)]
    [InlineData(25, false)]
    public void TheRangeIsAcceptedUpToTheMonthsItMayCoverAndNoFurther(int months, bool accepted)
    {
        var from = new DateOnly(2026, 1, 1);
        var request = Asked(from, from.AddMonths(months - 1).AddDays(14));

        if (!accepted)
        {
            Assert.Throws<ValidationException>(() => ReportRange.Require(request));

            return;
        }

        Assert.Equal(months, ReportRange.Require(request).Months().Count());
    }

    [Fact]
    public void OneDayIsOneMonthAndTheRangeIsAccepted()
    {
        var day = new DateOnly(2026, 5, 14);

        Assert.Equal([(2026, 5)], ReportRange.Require(Asked(day, day)).Months());
    }

    [Fact]
    public void TheMonthsRunAcrossTheYearAndIncludeBothEnds()
    {
        var range = ReportRange.Require(
            Asked(new DateOnly(2025, 11, 20), new DateOnly(2026, 2, 3)));

        Assert.Equal([(2025, 11), (2025, 12), (2026, 1), (2026, 2)], range.Months());
    }

    [Fact]
    public void TheRangeEndsAtTheMidnightAfterItsClosingDate()
    {
        var range = ReportRange.Require(
            Asked(new DateOnly(2026, 1, 1), new DateOnly(2026, 1, 31)));

        Assert.Equal(new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc), range.FromUtc);
        Assert.Equal(new DateTime(2026, 2, 1, 0, 0, 0, DateTimeKind.Utc), range.UntilUtc);
        Assert.Equal(DateTimeKind.Utc, range.UntilUtc.Kind);
    }

    // The bound is the midnight after the closing date, and the last date the
    // calendar holds has no day after it. Left unchecked the range validates
    // and the arithmetic behind it throws, which is a 500 for a bad request.
    [Fact]
    public void ARangeClosingOnTheLastDateThereIsRefusedRatherThanThrowing()
    {
        var refused = Assert.Throws<ValidationException>(() => ReportRange.Require(
            Asked(DateOnly.MaxValue.AddMonths(-2), DateOnly.MaxValue)));

        Assert.Contains(nameof(ReportRangeRequest.To), refused.Errors.Keys);
    }

    // Walking the months is the other place the last month of the calendar can
    // be stepped past, and it is reached only by enumerating them.
    [Fact]
    public void TheDayBeforeTheLastDateThereIsAnswersAndItsMonthsAreWalked()
    {
        var closes = DateOnly.MaxValue.AddDays(-1);

        var range = ReportRange.Require(Asked(closes.AddMonths(-2), closes));

        Assert.Equal(DateOnly.MaxValue, DateOnly.FromDateTime(range.UntilUtc));
        Assert.Equal(
            [(9999, 10), (9999, 11), (9999, 12)],
            range.Months());
    }

    private static ReportRangeRequest Asked(DateOnly? from, DateOnly? to) =>
        new() { From = from, To = to };
}
