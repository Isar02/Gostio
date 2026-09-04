using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

// The filter has to answer exactly what the booking will: a listing the search
// offers and CreateAsync then refuses is worse than no filter at all, because
// the refusal arrives after the guest has chosen.
[Collection(DatabaseCollection.Name)]
public class StaySearchTests(DatabaseFixture fixture)
{
    private readonly ReservationWorkspace workspace = new(fixture);

    private readonly DateOnly checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(40));

    [Fact]
    public async Task AListingWithNothingOverTheNightsIsOffered()
    {
        var (host, listing) = await workspace.AListingAsync();

        Assert.Equal([listing], await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    [Fact]
    public async Task ARangeTheHostClosedTakesTheListingOut()
    {
        var (host, listing) = await workspace.AListingAsync();

        await workspace.CloseAsync(host, listing, checkIn.AddDays(1), checkIn.AddDays(1));

        Assert.Empty(await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    // The range is inclusive on both ends and the stay is half open, so the one
    // that ends the day before the arrival closes no night being asked for.
    [Fact]
    public async Task AClosedRangeThatEndsBeforeTheArrivalLeavesTheListingOffered()
    {
        var (host, listing) = await workspace.AListingAsync();

        await workspace.CloseAsync(host, listing, checkIn.AddDays(-3), checkIn.AddDays(-1));

        Assert.Equal([listing], await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    [Fact]
    public async Task ABookingOverTheNightsTakesTheListingOut()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, checkIn.AddDays(1), nights: 1);

        Assert.Empty(await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    // Somebody else's check-out day is a night nobody bought, and the guest
    // arriving on it is the whole reason the stay is half open.
    [Fact]
    public async Task ABookingThatOnlyEndsOnTheArrivalDayLeavesTheListingOffered()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, checkIn.AddDays(-3), nights: 3);

        Assert.Equal([listing], await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    [Fact]
    public async Task ABookingThatBeginsOnTheDepartureDayLeavesTheListingOffered()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, checkIn.AddDays(3), nights: 2);

        Assert.Equal([listing], await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    [Fact]
    public async Task AHoldThatLapsedStopsExcludingAnything()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var held = await workspace.BookStayAsync(guest, listing, checkIn, nights: 3);

        Assert.Empty(await FoundByAsync(host, checkIn, checkIn.AddDays(3)));

        await workspace.LapseAsync(held.Id);

        Assert.Equal([listing], await FoundByAsync(host, checkIn, checkIn.AddDays(3)));
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task OneBoundOnItsOwnIsRefused(bool hasFrom, bool hasTo)
    {
        var (host, _) = await workspace.AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => FoundByAsync(
                host,
                hasFrom ? checkIn : null,
                hasTo ? checkIn.AddDays(3) : null));

        Assert.Contains(
            hasFrom
                ? nameof(AccommodationSearchRequest.AvailableTo)
                : nameof(AccommodationSearchRequest.AvailableFrom),
            refused.Errors.Keys);
    }

    [Fact]
    public async Task AWindowOfNoNightsIsRefused()
    {
        var (host, _) = await workspace.AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => FoundByAsync(host, checkIn, checkIn));

        Assert.Contains(nameof(AccommodationSearchRequest.AvailableTo), refused.Errors.Keys);
    }

    // Narrowing and never widening: the dates take listings away from the page
    // the same caller would otherwise see, and add none to it.
    [Fact]
    public async Task TheDatesOnlyTakeListingsAway()
    {
        var (host, booked) = await workspace.AListingAsync();
        var free = await workspace.AnotherListingAsync(host);
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, booked, checkIn, nights: 3);

        var all = await FoundByAsync(host, null, null);
        var open = await FoundByAsync(host, checkIn, checkIn.AddDays(3));

        Assert.Equal([booked, free], all.Order());
        Assert.Equal([free], open);
    }

    private async Task<IReadOnlyList<int>> FoundByAsync(int host, DateOnly? from, DateOnly? to)
    {
        var page = await workspace.SearchStaysAsync(
            host,
            RoleNames.Host,
            new AccommodationSearchRequest
            {
                HostId = host,
                AvailableFrom = from,
                AvailableTo = to,
            });

        return [.. page.Items.Select(item => item.Id)];
    }
}
