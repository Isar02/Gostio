using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Responses;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class HostReportTests(DatabaseFixture fixture)
{
    private readonly ReportWorkspace workspace = new(fixture);

    [Fact]
    public async Task AHostIsCountedOnWhatTheyHostedAndOnNothingElse()
    {
        var place = await workspace.APlaceAsync("hosts counted apart");
        var mine = await workspace.AHostAsync();
        var theirs = await workspace.AHostAsync();

        var booked = await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: mine), At(2001, 1, 10));

        var elsewhere = await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: theirs), At(2001, 1, 11));

        await workspace.AChargeAsync(booked, 400m, At(2001, 1, 12));
        await workspace.AChargeAsync(elsewhere, 900m, At(2001, 1, 13));

        var report = await workspace.MyRevenueAsync(mine, First(2001), Last(2001));
        var platform = await workspace.RevenueAsync(First(2001), Last(2001));

        Assert.Equal(1, report.Totals.BookingsCreated);
        Assert.Equal(400m, report.Totals.GrossCharged);
        Assert.Equal(2, platform.Totals.BookingsCreated);
        Assert.Equal(1300m, platform.Totals.GrossCharged);
    }

    [Fact]
    public async Task ARefundComesOffTheHostsNetAsItDoesOffThePlatforms()
    {
        var place = await workspace.APlaceAsync("hosts refunded");
        var mine = await workspace.AHostAsync();
        var theirs = await workspace.AHostAsync();

        var booked = await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: mine), At(2002, 1, 10));

        var elsewhere = await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: theirs), At(2002, 1, 11));

        var charge = await workspace.AChargeAsync(booked, 400m, At(2002, 1, 12));
        var otherCharge = await workspace.AChargeAsync(elsewhere, 900m, At(2002, 1, 13));

        await workspace.ARefundAsync(charge, 100m, At(2002, 2, 3));
        await workspace.ARefundAsync(otherCharge, 300m, At(2002, 2, 4));

        var report = await workspace.MyRevenueAsync(mine, First(2002), Last(2002));

        Assert.Equal(400m, Month(report, 1).GrossCharged);
        Assert.Equal(100m, Month(report, 2).Refunded);
        Assert.Equal(300m, report.Totals.Net);
    }

    [Fact]
    public async Task AMoveOnSomebodyElsesBookingIsNotTheHostsCompletion()
    {
        var place = await workspace.APlaceAsync("hosts completed apart");
        var mine = await workspace.AHostAsync();
        var theirs = await workspace.AHostAsync();

        var booked = await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: mine), At(2003, 1, 10));

        var elsewhere = await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: theirs), At(2003, 1, 11));

        await workspace.CompletedAsync(booked, At(2003, 2, 1));
        await workspace.CompletedAsync(elsewhere, At(2003, 2, 2));

        var report = await workspace.MyRevenueAsync(mine, First(2003), Last(2003));

        Assert.Equal(1, report.Totals.BookingsCompleted);
    }

    [Fact]
    public async Task AHostsCatalogueHoldsTheirListingsAndCountsTheirBookings()
    {
        var place = await workspace.APlaceAsync("hosts catalogue");
        var mine = await workspace.AHostAsync();
        var theirs = await workspace.AHostAsync();

        var listing = await workspace.AnAccommodationAsync(place, owner: mine);

        var otherListing = await workspace.AnAccommodationAsync(place, owner: theirs);

        var booked = await workspace.ABookingAsync(listing, At(2004, 1, 10), nights: 3);
        var elsewhere = await workspace.ABookingAsync(
            otherListing, At(2004, 1, 11), nights: 7);

        await workspace.AReviewAsync(booked, rating: 5);
        await workspace.AReviewAsync(elsewhere, rating: 1);
        await workspace.AChargeAsync(booked, 400m, At(2004, 1, 12));
        await workspace.AChargeAsync(elsewhere, 900m, At(2004, 1, 13));

        var report = await workspace.MyListingsAsync(
            mine, First(2004), Last(2004), SearchTarget.Accommodations);

        var row = Assert.Single(report.Rows);

        Assert.Equal(place.CityId, row.CityId);
        Assert.Equal(1, row.ListingsPublished);
        Assert.Equal(1, row.Bookings);
        Assert.Equal(3, row.UnitsSold);
        Assert.Equal(400m, row.GrossCharged);
        Assert.Equal(5m, row.AverageRating);
        Assert.Equal(1, row.ReviewCount);
    }

    [Fact]
    public async Task AHostsCatalogueAnswersOnTheExperienceSideTheSameWay()
    {
        var city = (await workspace.APlaceAsync("hosts terms")).CityId;
        var category = await workspace.AnExperienceCategoryAsync("hosts terms");
        var mine = await workspace.AHostAsync();
        var theirs = await workspace.AHostAsync();

        var experience = await workspace.AnExperienceAsync(city, category, owner: mine);
        var term = await workspace.ATermAsync(experience, At(2005, 6, 1));

        var otherExperience = await workspace.AnExperienceAsync(city, category, owner: theirs);
        var otherTerm = await workspace.ATermAsync(otherExperience, At(2005, 6, 2));

        var booked = await workspace.ASeatedBookingAsync(term, At(2005, 1, 10), seats: 4);
        var elsewhere = await workspace.ASeatedBookingAsync(
            otherTerm, At(2005, 1, 11), seats: 7);

        await workspace.AReviewAsync(booked, rating: 5);
        await workspace.AReviewAsync(elsewhere, rating: 1);
        await workspace.AChargeAsync(booked, 160m, At(2005, 1, 12));
        await workspace.AChargeAsync(elsewhere, 700m, At(2005, 1, 13));

        var report = await workspace.MyListingsAsync(
            mine, First(2005), Last(2005), SearchTarget.Experiences);

        var row = Assert.Single(report.Rows);

        Assert.Equal(1, row.ListingsPublished);
        Assert.Equal(1, row.Bookings);
        Assert.Equal(4, row.UnitsSold);
        Assert.Equal(160m, row.GrossCharged);
        Assert.Equal(5m, row.AverageRating);
        Assert.Equal(1, row.ReviewCount);
    }

    [Fact]
    public async Task TheHostDocumentNarrowsForAnAccountThatIsAlsoAnAdministrator()
    {
        var place = await workspace.APlaceAsync("both roles");
        var both = await workspace.AHostAsync(RoleNames.Administrator, RoleNames.Host);
        var theirs = await workspace.AHostAsync();

        await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: both), At(2006, 1, 10));

        await workspace.ABookingAsync(
            await workspace.AnAccommodationAsync(place, owner: theirs), At(2006, 1, 11));

        var mine = await workspace.MyRevenueAsync(
            both, First(2006), Last(2006), RoleNames.Administrator, RoleNames.Host);

        var platform = await workspace.RevenueAsync(First(2006), Last(2006));

        var myListings = await workspace.MyListingsAsync(
            both,
            First(2006),
            Last(2006),
            SearchTarget.Accommodations,
            RoleNames.Administrator,
            RoleNames.Host);

        var platformListings = await workspace.ListingsAsync(
            First(2006), Last(2006), SearchTarget.Accommodations);

        Assert.Equal(1, mine.Totals.BookingsCreated);
        Assert.Equal(2, platform.Totals.BookingsCreated);
        Assert.Equal(1, Assert.Single(myListings.Rows).ListingsPublished);
        Assert.Equal(
            2,
            platformListings.Rows.Single(row => row.CityId == place.CityId).ListingsPublished);
    }

    private static DateTime At(int year, int month, int day) =>
        new(year, month, day, 12, 0, 0, DateTimeKind.Utc);

    private static DateOnly First(int year) => new(year, 1, 1);

    private static DateOnly Last(int year) => new(year, 3, 31);

    private static RevenueReportRow Month(RevenueReportResponse report, int month) =>
        report.Rows.Single(row => row.Month == month);
}
