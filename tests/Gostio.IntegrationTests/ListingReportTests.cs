using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Responses;

namespace Gostio.IntegrationTests;

// Rows cover the whole catalogue and only the activity is scoped by the range,
// so a test owns a city and a category of its own as well as a year of its own.
// Both are what make the figures exact in a database every suite writes into.
[Collection(DatabaseCollection.Name)]
public class ListingReportTests(DatabaseFixture fixture)
{
    private readonly ReportWorkspace workspace = new(fixture);

    [Fact]
    public async Task ACityAndCategoryWithListingsAndNoActivityIsStillARow()
    {
        var place = await workspace.APlaceAsync("quiet corner");

        await workspace.AnAccommodationAsync(place);
        await workspace.AnAccommodationAsync(place);

        var row = await RowFor(place, 2021);

        Assert.Equal(2, row.ListingsPublished);
        Assert.Equal(0, row.Bookings);
        Assert.Equal(0m, row.GrossCharged);
        Assert.Null(row.AverageRating);
    }

    // The listings column counts what stands in the catalogue now, and every
    // other column counts what happened inside the range. A row saying two
    // listings took forty bookings is the reason the two are read differently.
    [Fact]
    public async Task AWithdrawnListingIsNotCountedAsPublishedAndItsBookingsStillAre()
    {
        var place = await workspace.APlaceAsync("withdrawn corner");

        var taken = await workspace.AnAccommodationAsync(place, published: false);

        await workspace.AnAccommodationAsync(place);
        await workspace.ABookingAsync(taken, At(2022, 2, 2), nights: 3);

        var row = await RowFor(place, 2022);

        Assert.Equal(1, row.ListingsPublished);
        Assert.Equal(1, row.Bookings);
        Assert.Equal(3, row.UnitsSold);
    }

    [Fact]
    public async Task AStaySellsTheNightsBetweenItsDates()
    {
        var place = await workspace.APlaceAsync("nights");
        var listing = await workspace.AnAccommodationAsync(place);

        await workspace.ABookingAsync(listing, At(2023, 1, 10), nights: 4);
        await workspace.ABookingAsync(listing, At(2023, 2, 10), nights: 3);

        var row = await RowFor(place, 2023);

        Assert.Equal(2, row.Bookings);
        Assert.Equal(7, row.UnitsSold);
    }

    [Fact]
    public async Task ATermSellsTheSeatsItsPartiesTookAndNotTheNightsAStayWould()
    {
        var city = (await workspace.APlaceAsync("seats")).CityId;
        var category = await workspace.AnExperienceCategoryAsync("seats");

        var listing = await workspace.AnExperienceAsync(city, category);
        var term = await workspace.ATermAsync(listing, At(2024, 5, 1));

        await workspace.ASeatedBookingAsync(term, At(2024, 1, 15), seats: 3);
        await workspace.ASeatedBookingAsync(term, At(2024, 3, 2), seats: 2);

        var row = await RowFor(city, category, 2024, SearchTarget.Experiences);

        Assert.Equal(1, row.ListingsPublished);
        Assert.Equal(2, row.Bookings);
        Assert.Equal(5, row.UnitsSold);
    }

    [Fact]
    public async Task ACancelledBookingSellsNothing()
    {
        var place = await workspace.APlaceAsync("cancelled");
        var listing = await workspace.AnAccommodationAsync(place);

        await workspace.ABookingAsync(
            listing, At(2025, 2, 5), status: ReservationStatusCode.Cancelled, nights: 5);

        await workspace.ABookingAsync(
            listing, At(2025, 2, 6), status: ReservationStatusCode.Completed, nights: 2);

        var row = await RowFor(place, 2025);

        Assert.Equal(1, row.Bookings);
        Assert.Equal(2, row.UnitsSold);
    }

    [Fact]
    public async Task TheMoneyIsWhatSettledAgainstTheBookingsMadeInTheRange()
    {
        var place = await workspace.APlaceAsync("money");
        var listing = await workspace.AnAccommodationAsync(place);

        var inside = await workspace.ABookingAsync(listing, At(2026, 2, 1), price: 700m);
        var outside = await workspace.ABookingAsync(listing, At(2026, 6, 1), price: 700m);

        await workspace.AChargeAsync(inside, 650m, At(2026, 2, 2));
        await workspace.AChargeAsync(outside, 650m, At(2026, 6, 2));

        var row = await RowFor(place, 2026);

        Assert.Equal(650m, row.GrossCharged);
    }

    [Fact]
    public async Task TheRatingIsWeighedOverTheReviewsRatherThanOverTheListings()
    {
        var place = await workspace.APlaceAsync("rated");
        var listing = await workspace.AnAccommodationAsync(place);

        var first = await workspace.ABookingAsync(listing, At(2027, 1, 4));
        var second = await workspace.ABookingAsync(listing, At(2027, 1, 5));
        var third = await workspace.ABookingAsync(listing, At(2027, 1, 6));

        await workspace.AReviewAsync(first, 5);
        await workspace.AReviewAsync(second, 4);
        await workspace.AReviewAsync(third, 4);

        var row = await RowFor(place, 2027);

        Assert.Equal(3, row.ReviewCount);
        Assert.Equal(4.33m, row.AverageRating);
    }

    // One row rated five once and another rated three three times. Weighed over
    // the reviews that is 3.5; averaged over the rows it would be 4, which is
    // the implementation this has to fail.
    [Fact]
    public async Task TheTotalRatingIsWeighedOverTheReviewsAndNotOverTheRows()
    {
        var seldom = await workspace.APlaceAsync("seldom rated");
        var often = await workspace.APlaceAsync("often rated");

        await workspace.AReviewAsync(await AStayAsync(seldom, 2028), 5);

        foreach (var _ in Enumerable.Range(0, 3))
        {
            await workspace.AReviewAsync(await AStayAsync(often, 2028), 3);
        }

        var report = await ReportIn(2028, SearchTarget.Accommodations);

        Assert.Equal(1, Row(report, seldom).ReviewCount);
        Assert.Equal(5m, Row(report, seldom).AverageRating);
        Assert.Equal(3, Row(report, often).ReviewCount);
        Assert.Equal(3m, Row(report, often).AverageRating);

        Assert.Equal(4, report.Totals.ReviewCount);
        Assert.Equal(3.5m, report.Totals.AverageRating);
    }

    [Fact]
    public async Task TheTotalsAddUpTheRowsTheyStandUnder()
    {
        var report = await ReportIn(2030, SearchTarget.Accommodations);

        Assert.Equal(
            report.Rows.Sum(row => row.ListingsPublished), report.Totals.ListingsPublished);
        Assert.Equal(report.Rows.Sum(row => row.Bookings), report.Totals.Bookings);
        Assert.Equal(report.Rows.Sum(row => row.UnitsSold), report.Totals.UnitsSold);
        Assert.Equal(report.Rows.Sum(row => row.GrossCharged), report.Totals.GrossCharged);
        Assert.Equal(report.Rows.Sum(row => row.ReviewCount), report.Totals.ReviewCount);
    }

    [Fact]
    public async Task TheCurrencyIsReadOffTheMoneyAndNotOffTheConfiguration()
    {
        var place = await workspace.APlaceAsync("in marks");
        var listing = await workspace.AnAccommodationAsync(place);

        var booking = await workspace.ABookingAsync(listing, At(2031, 2, 4));

        await workspace.AChargeAsync(booking, 320m, At(2031, 2, 5), currency: "bam");

        var report = await ReportIn(2031, SearchTarget.Accommodations);

        Assert.NotEqual("bam", fixture.Stripe.Currency);
        Assert.Equal("bam", report.Currency);
        Assert.Equal(320m, Row(report, place).GrossCharged);
    }

    [Fact]
    public async Task ARangeHoldingTwoCurrenciesIsRefusedRatherThanAddedUp()
    {
        var place = await workspace.APlaceAsync("two currencies");
        var listing = await workspace.AnAccommodationAsync(place);

        var inEuros = await workspace.ABookingAsync(listing, At(2032, 1, 4));
        var inMarks = await workspace.ABookingAsync(listing, At(2032, 2, 4));

        await workspace.AChargeAsync(inEuros, 100m, At(2032, 1, 5), currency: "eur");
        await workspace.AChargeAsync(inMarks, 100m, At(2032, 2, 5), currency: "bam");

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => ReportIn(2032, SearchTarget.Accommodations));

        Assert.Contains("bam and eur", refused.Message);
    }

    [Fact]
    public async Task TheReportNamesTheCatalogueItCovers()
    {
        var report = await workspace.ListingsAsync(
            new DateOnly(2029, 1, 1), new DateOnly(2029, 3, 31), SearchTarget.Experiences);

        Assert.Equal(SearchTarget.Experiences, report.Target);
        Assert.Equal(fixture.Stripe.Currency, report.Currency);
    }

    [Fact]
    public async Task AReportThatNamesNoCatalogueIsRefusedUnderItsOwnField()
    {
        var refused = await Assert.ThrowsAsync<ValidationException>(() => workspace.ListingsAsync(
            new DateOnly(2029, 1, 1), new DateOnly(2029, 3, 31), target: null));

        Assert.Contains("Target", refused.Errors.Keys);
    }

    private static DateTime At(int year, int month, int day) =>
        new(year, month, day, 12, 0, 0, DateTimeKind.Utc);

    private static ListingReportRow Row(ListingReportResponse report, ReportedPlace place) =>
        report.Rows.Single(row =>
            row.CityId == place.CityId && row.CategoryId == place.CategoryId);

    private async Task<int> AStayAsync(ReportedPlace place, int year)
    {
        var listing = await workspace.AnAccommodationAsync(place);

        return await workspace.ABookingAsync(listing, At(year, 2, 1));
    }

    private Task<ListingReportResponse> ReportIn(int year, SearchTarget target) =>
        workspace.ListingsAsync(
            new DateOnly(year, 1, 1), new DateOnly(year, 3, 31), target);

    private Task<ListingReportRow> RowFor(ReportedPlace place, int year) =>
        RowFor(place.CityId, place.CategoryId, year, SearchTarget.Accommodations);

    private async Task<ListingReportRow> RowFor(
        int cityId,
        int categoryId,
        int year,
        SearchTarget target)
    {
        var report = await workspace.ListingsAsync(
            new DateOnly(year, 1, 1), new DateOnly(year, 3, 31), target);

        return report.Rows.Single(row => row.CityId == cityId && row.CategoryId == categoryId);
    }
}
