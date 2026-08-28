using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Responses;

namespace Gostio.IntegrationTests;

// The report aggregates over whole tables, and every suite in this collection —
// this one included — writes into the same database. So each test owns a year
// nothing else writes into, and the figures are exact rather than merely larger
// than something. Every other suite books at the current moment, which is what
// leaves these years free.
[Collection(DatabaseCollection.Name)]
public class RevenueReportTests(DatabaseFixture fixture)
{
    private readonly ReportWorkspace workspace = new(fixture);

    [Fact]
    public async Task EveryMonthOfTheRangeGetsARowEvenWhenNothingHappenedInIt()
    {
        var report = await ReportFor(2011);

        Assert.Equal([(2011, 1), (2011, 2), (2011, 3)], Months(report));
        Assert.Equal(0, report.Totals.BookingsCreated);
    }

    [Fact]
    public async Task ABookingIsCountedInTheMonthItWasMadeAndInTheMonthItFinished()
    {
        var listing = await workspace.AListingAsync();

        var booking = await workspace.ABookingAsync(listing, At(2012, 1, 20));

        await workspace.CompletedAsync(booking, At(2012, 3, 4));

        var report = await ReportFor(2012);

        Assert.Equal(1, Month(report, 1).BookingsCreated);
        Assert.Equal(0, Month(report, 1).BookingsCompleted);
        Assert.Equal(0, Month(report, 3).BookingsCreated);
        Assert.Equal(1, Month(report, 3).BookingsCompleted);
    }

    [Fact]
    public async Task TheMoneyIsWhatWasChargedAndRefundedRatherThanWhatWasPriced()
    {
        var listing = await workspace.AListingAsync();

        var booking = await workspace.ABookingAsync(listing, At(2013, 2, 3), price: 500m);
        var charge = await workspace.AChargeAsync(booking, 400m, At(2013, 2, 4));

        await workspace.ARefundAsync(charge, 100m, At(2013, 2, 20));

        var february = Month(await ReportFor(2013), 2);

        Assert.Equal(400m, february.GrossCharged);
        Assert.Equal(100m, february.Refunded);
        Assert.Equal(300m, february.Net);
    }

    [Fact]
    public async Task ARefundLandsInItsOwnMonthAndNotTheChargesOne()
    {
        var listing = await workspace.AListingAsync();

        var booking = await workspace.ABookingAsync(listing, At(2014, 1, 5));
        var charge = await workspace.AChargeAsync(booking, 300m, At(2014, 1, 6));

        await workspace.ARefundAsync(charge, 300m, At(2014, 3, 9));

        var report = await ReportFor(2014);

        Assert.Equal(300m, Month(report, 1).GrossCharged);
        Assert.Equal(300m, Month(report, 1).Net);
        Assert.Equal(0m, Month(report, 3).GrossCharged);
        Assert.Equal(-300m, Month(report, 3).Net);
    }

    [Fact]
    public async Task AChargeThatNeverSettledAndARefundThatFailedAreLeftOut()
    {
        var listing = await workspace.AListingAsync();

        // Two bookings rather than two charges on one: a reservation may hold
        // only one payment that is pending or succeeded.
        var abandoned = await workspace.ABookingAsync(listing, At(2015, 2, 10));
        var paid = await workspace.ABookingAsync(listing, At(2015, 2, 10));

        await workspace.AChargeAsync(abandoned, 250m, processedAt: null, PaymentStatus.Pending);

        var settled = await workspace.AChargeAsync(paid, 250m, At(2015, 2, 11));

        await workspace.ARefundAsync(settled, 50m, At(2015, 2, 12), RefundStatus.Failed);

        var february = Month(await ReportFor(2015), 2);

        Assert.Equal(250m, february.GrossCharged);
        Assert.Equal(0m, february.Refunded);
    }

    [Fact]
    public async Task TheClosingDayOfTheRangeIsWholeRatherThanItsMidnight()
    {
        var listing = await workspace.AListingAsync();

        var booking = await workspace.ABookingAsync(listing, At(2016, 3, 31, 23));

        await workspace.AChargeAsync(booking, 120m, At(2016, 3, 31, 23));

        var march = Month(await ReportFor(2016), 3);

        Assert.Equal(1, march.BookingsCreated);
        Assert.Equal(120m, march.GrossCharged);
    }

    [Fact]
    public async Task WhatFallsOutsideTheRangeIsNotReported()
    {
        var listing = await workspace.AListingAsync();

        var before = await workspace.ABookingAsync(listing, At(2016, 12, 31, 23));
        var after = await workspace.ABookingAsync(listing, At(2017, 4, 1));

        await workspace.AChargeAsync(before, 90m, At(2016, 12, 31, 23));
        await workspace.AChargeAsync(after, 90m, At(2017, 4, 1));

        var report = await ReportFor(2017);

        Assert.Equal(0, report.Totals.BookingsCreated);
        Assert.Equal(0m, report.Totals.GrossCharged);
    }

    [Fact]
    public async Task TheTotalsAddUpTheRowsTheyStandUnder()
    {
        var listing = await workspace.AListingAsync();

        var january = await workspace.ABookingAsync(listing, At(2018, 1, 8));
        var march = await workspace.ABookingAsync(listing, At(2018, 3, 8));

        await workspace.CompletedAsync(january, At(2018, 2, 1));
        await workspace.AChargeAsync(january, 200m, At(2018, 1, 9));

        var charge = await workspace.AChargeAsync(march, 800m, At(2018, 3, 9));

        await workspace.ARefundAsync(charge, 300m, At(2018, 3, 10));

        var report = await ReportFor(2018);

        Assert.Equal(2, report.Totals.BookingsCreated);
        Assert.Equal(1, report.Totals.BookingsCompleted);
        Assert.Equal(1000m, report.Totals.GrossCharged);
        Assert.Equal(300m, report.Totals.Refunded);
        Assert.Equal(700m, report.Totals.Net);
        Assert.Equal(report.Rows.Sum(row => row.Net), report.Totals.Net);
    }

    [Fact]
    public async Task ARangeThatSettledNothingCarriesTheConfiguredCurrency()
    {
        var report = await ReportFor(2019);

        Assert.Equal(fixture.Stripe.Currency, report.Currency);
        Assert.Equal(new DateOnly(2019, 1, 1), report.From);
        Assert.Equal(new DateOnly(2019, 3, 31), report.To);
    }

    [Fact]
    public async Task TheCurrencyIsReadOffTheMoneyAndNotOffTheConfiguration()
    {
        var listing = await workspace.AListingAsync();

        var booking = await workspace.ABookingAsync(listing, At(2009, 2, 3));

        await workspace.AChargeAsync(
            booking, 240m, At(2009, 2, 4), currency: "bam");

        var report = await ReportFor(2009);

        Assert.NotEqual("bam", fixture.Stripe.Currency);
        Assert.Equal("bam", report.Currency);
        Assert.Equal(240m, Month(report, 2).GrossCharged);
    }

    [Fact]
    public async Task ARangeHoldingTwoCurrenciesIsRefusedRatherThanAddedUp()
    {
        var listing = await workspace.AListingAsync();

        var inEuros = await workspace.ABookingAsync(listing, At(2010, 1, 3));
        var inMarks = await workspace.ABookingAsync(listing, At(2010, 2, 3));

        await workspace.AChargeAsync(inEuros, 100m, At(2010, 1, 4), currency: "eur");
        await workspace.AChargeAsync(inMarks, 100m, At(2010, 2, 4), currency: "bam");

        var refused = await Assert.ThrowsAsync<BusinessException>(() => ReportFor(2010));

        Assert.Contains("bam and eur", refused.Message);
    }

    [Fact]
    public async Task ARefundIsCountedInTheCurrencyOfTheChargeItCameFrom()
    {
        var listing = await workspace.AListingAsync();

        var booking = await workspace.ABookingAsync(listing, At(2007, 12, 1));
        var charge = await workspace.AChargeAsync(
            booking, 400m, At(2007, 12, 2), currency: "bam");

        await workspace.ARefundAsync(charge, 150m, At(2008, 2, 5));

        var report = await ReportFor(2008);

        Assert.Equal("bam", report.Currency);
        Assert.Equal(150m, Month(report, 2).Refunded);
    }

    private static DateTime At(int year, int month, int day, int hour = 12) =>
        new(year, month, day, hour, 0, 0, DateTimeKind.Utc);

    private static IReadOnlyList<(int, int)> Months(RevenueReportResponse report) =>
        [.. report.Rows.Select(row => (row.Year, row.Month))];

    private static RevenueReportRow Month(RevenueReportResponse report, int month) =>
        report.Rows.Single(row => row.Month == month);

    private Task<RevenueReportResponse> ReportFor(int year) =>
        workspace.RevenueAsync(new DateOnly(year, 1, 1), new DateOnly(year, 3, 31));
}
