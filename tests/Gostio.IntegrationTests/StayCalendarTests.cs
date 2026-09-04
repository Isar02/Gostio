using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;

namespace Gostio.IntegrationTests;

// What the guest picks on. A day is unbookable when the host closed it or
// somebody has it, and the grid marks the nights [check-in, check-out): a
// client that greyed the departure day would paint a night nobody bought.
[Collection(DatabaseCollection.Name)]
public class StayCalendarTests(DatabaseFixture fixture)
{
    private const decimal BasePrice = 100m;

    private readonly ReservationWorkspace workspace = new(fixture);

    private readonly DateOnly first = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(50));

    [Fact]
    public async Task ADayTheHostClosedCannotBeBooked()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);

        await workspace.CloseAsync(host, listing, first.AddDays(1), first.AddDays(2));

        var days = await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(3));

        Assert.Equal([true, false, false, true], Bookable(days));
    }

    [Fact]
    public async Task ADaySomebodyHasBookedCannotBeBookedEither()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, first.AddDays(1), nights: 2);

        var days = await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(3));

        Assert.Equal([true, false, false, true], Bookable(days));
    }

    [Fact]
    public async Task ADayCarryingBothIsStillOneDay()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, first.AddDays(1), nights: 1);
        await workspace.CloseAsync(host, listing, first.AddDays(1), first.AddDays(1));

        var days = await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(2));

        Assert.Equal([true, false, true], Bookable(days));
    }

    [Fact]
    public async Task AHoldThatLapsedLeavesItsNightsBookable()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);
        var guest = await workspace.AGuestAsync();

        var held = await workspace.BookStayAsync(guest, listing, first, nights: 2);

        await workspace.LapseAsync(held.Id);

        var days = await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(2));

        Assert.All(days, day => Assert.True(day.IsBookable));
    }

    // The same method the booking totals itself with, so a night cannot cost one
    // amount on the grid and another on the way out.
    [Fact]
    public async Task ARepricedRangeIsReportedAtItsOverrideAndTheRestAtTheBasePrice()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);

        await workspace.RepriceAsync(host, listing, first.AddDays(1), first.AddDays(2), 175m);

        var days = await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(3));

        Assert.Equal(
            [BasePrice, 175m, 175m, BasePrice],
            Priced(days));
    }

    // Both ends are inclusive, so the bound counts the days answered rather than
    // the days between them.
    [Theory]
    [InlineData(0, 1)]
    [InlineData(StayCalendarWindow.MaximumDays - 1, StayCalendarWindow.MaximumDays)]
    public async Task AWindowIsAnsweredADayAtATime(int span, int expected)
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);

        var days = await CalendarAsync(
            host, RoleNames.Host, listing, first, first.AddDays(span));

        Assert.Equal(expected, days.Count);
        Assert.Equal(first, days[0].Date);
        Assert.Equal(first.AddDays(span), days[^1].Date);
    }

    [Fact]
    public async Task AWindowLongerThanTheBoundIsRefused()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => CalendarAsync(
                host,
                RoleNames.Host,
                listing,
                first,
                first.AddDays(StayCalendarWindow.MaximumDays)));

        Assert.Contains(nameof(StayCalendarRequest.To), refused.Errors.Keys);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    [InlineData(false, false)]
    public async Task AWindowMissingEitherDayIsRefused(bool hasFrom, bool hasTo)
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.CalendarAsync(
                host,
                RoleNames.Host,
                listing,
                new StayCalendarRequest
                {
                    From = hasFrom ? first : null,
                    To = hasTo ? first.AddDays(3) : null,
                }));
    }

    // The calendar follows the listing it belongs to: an id nobody may read must
    // not become a way of learning that it exists.
    [Fact]
    public async Task AWithdrawnListingAnswersItsHostAndNobodyElse()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);
        var guest = await workspace.AGuestAsync();

        await workspace.WithdrawAsync(host, listing);

        Assert.NotEmpty(
            await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(3)));

        await Assert.ThrowsAsync<NotFoundException>(
            () => CalendarAsync(guest, RoleNames.Guest, listing, first, first.AddDays(3)));
    }

    [Fact]
    public async Task TheLastNightOfAStayIsTheNextGuestsFirstDay()
    {
        var (host, listing) = await workspace.AListingAsync(BasePrice);
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, first, nights: 2);

        var days = await CalendarAsync(host, RoleNames.Host, listing, first, first.AddDays(2));

        Assert.Equal([false, false, true], Bookable(days));
    }

    private static IReadOnlyList<bool> Bookable(IReadOnlyList<StayCalendarDayResponse> days) =>
        [.. days.Select(day => day.IsBookable)];

    private static IReadOnlyList<decimal> Priced(IReadOnlyList<StayCalendarDayResponse> days) =>
        [.. days.Select(day => day.Price)];

    private Task<IReadOnlyList<StayCalendarDayResponse>> CalendarAsync(
        int actor,
        string role,
        int listing,
        DateOnly from,
        DateOnly to) =>
        workspace.CalendarAsync(
            actor, role, listing, new StayCalendarRequest { From = from, To = to });
}
