using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Reservations;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReservationListTests(DatabaseFixture fixture)
{
    private readonly ReservationWorkspace workspace = new(fixture);

    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(60));

    private static DateTime Later => DateTime.UtcNow.AddDays(20);

    private static DateOnly TermDay => DateOnly.FromDateTime(DateTime.UtcNow).AddDays(20);

    // Mid-morning where the guest is standing, so the day the term belongs to
    // does not move with the hour the suite happens to run at.
    private static DateTime TermStart => StayTimes.StartOfDay(TermDay).AddHours(10);

    [Fact]
    public async Task AGuestSeesWhatTheyBookedAndNothingElse()
    {
        var (_, listing) = await workspace.AListingAsync();
        var mine = await workspace.AGuestAsync();
        var theirs = await workspace.AGuestAsync();

        var booked = await workspace.BookStayAsync(mine, listing, Soon, nights: 2);

        await workspace.BookStayAsync(theirs, listing, Soon.AddDays(5), nights: 2);

        var page = await workspace.ListAsync(mine, RoleNames.Guest, new ReservationSearchRequest());

        Assert.Equal([booked.Id], page.Items.Select(item => item.Id));
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task AStrangerSeesNoneOfIt()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var stranger = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        var page = await workspace.ListAsync(
            stranger, RoleNames.Guest, new ReservationSearchRequest { AccommodationId = listing });

        Assert.Empty(page.Items);
        Assert.Equal(0, page.TotalCount);
    }

    [Fact]
    public async Task AHostWhoIsAlsoAGuestSeparatesTheTwoSides()
    {
        var (host, listing) = await workspace.AListingAsync();
        var (_, elsewhere) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var received = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);
        var made = await workspace.BookStayAsync(host, elsewhere, Soon, nights: 2);

        var asHost = await workspace.ListAsync(
            host, RoleNames.Host, new ReservationSearchRequest { HostId = host });

        var asGuest = await workspace.ListAsync(
            host, RoleNames.Host, new ReservationSearchRequest { GuestId = host });

        var both = await workspace.ListAsync(host, RoleNames.Host, new ReservationSearchRequest());

        Assert.Equal([received.Id], asHost.Items.Select(item => item.Id));
        Assert.Equal([made.Id], asGuest.Items.Select(item => item.Id));
        Assert.Equal([made.Id, received.Id], both.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task AFilterCannotReachPastWhatTheCallerMaySee()
    {
        var (_, listing) = await workspace.AListingAsync();
        var mine = await workspace.AGuestAsync();
        var theirs = await workspace.AGuestAsync();

        await workspace.BookStayAsync(mine, listing, Soon, nights: 2);
        await workspace.BookStayAsync(theirs, listing, Soon.AddDays(5), nights: 2);

        var page = await workspace.ListAsync(
            mine, RoleNames.Guest, new ReservationSearchRequest { GuestId = theirs });

        Assert.Empty(page.Items);
    }

    [Fact]
    public async Task AnAdministratorSeesEveryBookingOnAListing()
    {
        var (_, listing) = await workspace.AListingAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var one = await workspace.AGuestAsync();
        var two = await workspace.AGuestAsync();

        var first = await workspace.BookStayAsync(one, listing, Soon, nights: 2);
        var second = await workspace.BookStayAsync(two, listing, Soon.AddDays(5), nights: 2);

        var page = await workspace.ListAsync(
            administrator,
            RoleNames.Administrator,
            new ReservationSearchRequest { AccommodationId = listing });

        Assert.Equal([second.Id, first.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheNewestBookingComesFirst()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var first = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);
        var second = await workspace.BookStayAsync(guest, listing, Soon.AddDays(5), nights: 2);

        var page = await workspace.ListAsync(guest, RoleNames.Guest, new ReservationSearchRequest());

        Assert.Equal([second.Id, first.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheListSeparatesWhatStillHoldsAPlaceFromWhatDoesNot()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var live = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);
        var cancelled = await workspace.BookStayAsync(guest, listing, Soon.AddDays(5), nights: 2);
        var lapsed = await workspace.BookStayAsync(guest, listing, Soon.AddDays(10), nights: 2);

        await workspace.CancelAsync(cancelled.Id);
        await workspace.LapseAsync(lapsed.Id);

        var holding = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { IsActive = true });

        var over = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { IsActive = false });

        Assert.Equal([live.Id], holding.Items.Select(item => item.Id));
        Assert.Equal([cancelled.Id, lapsed.Id], over.Items.Select(item => item.Id).Order());
    }

    [Fact]
    public async Task TheListNarrowsToOneStatus()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var confirmed = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.BookStayAsync(guest, listing, Soon.AddDays(5), nights: 2);
        await workspace.ConfirmAsync(host, RoleNames.Host, confirmed.Id);

        var page = await workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest
            {
                ReservationStatusId = (int)ReservationStatusCode.Confirmed,
            });

        Assert.Equal([confirmed.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheListNarrowsToOneTerm()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 10, startsAt: Later);
        var second = await workspace.AnotherTermAsync(host, slot, Later.AddDays(1));
        var guest = await workspace.AGuestAsync();

        var wanted = await workspace.BookTermAsync(guest, slot, guestCount: 2);

        await workspace.BookTermAsync(guest, second, guestCount: 2);

        var page = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { ExperienceSlotId = slot });

        Assert.Equal([wanted.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheListGathersAnExperienceAcrossItsTerms()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 10, startsAt: Later);
        var second = await workspace.AnotherTermAsync(host, slot, Later.AddDays(1));
        var (_, elsewhere) = await workspace.ATermAsync(capacity: 10, startsAt: Later);
        var guest = await workspace.AGuestAsync();

        var one = await workspace.BookTermAsync(guest, slot, guestCount: 2);
        var two = await workspace.BookTermAsync(guest, second, guestCount: 2);

        await workspace.BookTermAsync(guest, elsewhere, guestCount: 2);

        var experienceId = await workspace.ExperienceOfAsync(slot);

        var page = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { ExperienceId = experienceId });

        Assert.Equal([two.Id, one.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task ARowNamesWhatWasBookedAndWhoBookedIt()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        var page = await workspace.ListAsync(guest, RoleNames.Guest, new ReservationSearchRequest());
        var row = Assert.Single(page.Items);

        Assert.Equal(await workspace.TitleOfAsync(listing), row.ListingTitle);
        Assert.Equal("Integration Tests", row.GuestName);
        Assert.Null(row.ExperienceId);
    }

    [Fact]
    public async Task ARowOnATermNamesTheExperienceItBelongsTo()
    {
        var (_, slot) = await workspace.ATermAsync(capacity: 10, startsAt: Later);
        var guest = await workspace.AGuestAsync();

        await workspace.BookTermAsync(guest, slot, guestCount: 2);

        var page = await workspace.ListAsync(guest, RoleNames.Guest, new ReservationSearchRequest());
        var row = Assert.Single(page.Items);

        Assert.Equal(await workspace.ExperienceOfAsync(slot), row.ExperienceId);
        Assert.StartsWith("An experience ", row.ListingTitle);
    }

    [Fact]
    public async Task TheListIsPagedLikeEveryOther()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var first = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.BookStayAsync(guest, listing, Soon.AddDays(5), nights: 2);

        var page = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { Page = 2, PageSize = 1 });

        Assert.Equal([first.Id], page.Items.Select(item => item.Id));
        Assert.Equal(2, page.TotalCount);
        Assert.Equal(2, page.TotalPages);
    }

    [Fact]
    public async Task TheWindowKeepsAStayThatOccupiesANightInIt()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        // Ends on the day the window opens, so it occupies no night in it.
        await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        var inside = await workspace.BookStayAsync(guest, listing, Soon.AddDays(2), nights: 2);

        // Begins the day after the window closes.
        await workspace.BookStayAsync(guest, listing, Soon.AddDays(4), nights: 2);

        var page = await workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest { From = Soon.AddDays(2), To = Soon.AddDays(3) });

        Assert.Equal([inside.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheWindowReachesATermByTheDayItStartsOn()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 10, startsAt: TermStart);
        var later = await workspace.AnotherTermAsync(host, slot, TermStart.AddDays(3));
        var guest = await workspace.AGuestAsync();

        var wanted = await workspace.BookTermAsync(guest, slot, guestCount: 2);

        await workspace.BookTermAsync(guest, later, guestCount: 2);

        var page = await workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest { From = TermDay, To = TermDay });

        Assert.Equal([wanted.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheListNarrowsToWhatArrivesOnADay()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var arriving = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.BookStayAsync(guest, listing, Soon.AddDays(2), nights: 2);

        var page = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { ArrivesOn = Soon });

        Assert.Equal([arriving.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheDayAStayEndsIsADepartureAndNotAnArrival()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var leaving = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);
        var coming = await workspace.BookStayAsync(guest, listing, Soon.AddDays(2), nights: 2);

        var departures = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { DepartsOn = Soon.AddDays(2) });

        var arrivals = await workspace.ListAsync(
            guest, RoleNames.Guest, new ReservationSearchRequest { ArrivesOn = Soon.AddDays(2) });

        Assert.Equal([leaving.Id], departures.Items.Select(item => item.Id));
        Assert.Equal([coming.Id], arrivals.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task ADayOfArrivalsAndDeparturesIsPagedLikeEveryOtherList()
    {
        var guest = await workspace.AGuestAsync();
        var booked = new List<int>();

        foreach (var _ in Enumerable.Range(0, 3))
        {
            var (_, listing) = await workspace.AListingAsync();

            booked.Add((await workspace.BookStayAsync(guest, listing, Soon, nights: 2)).Id);
        }

        var arrivals = await workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest { ArrivesOn = Soon, Page = 2, PageSize = 2 });

        var departures = await workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest { DepartsOn = Soon.AddDays(2), Page = 2, PageSize = 2 });

        Assert.Equal([booked[0]], arrivals.Items.Select(item => item.Id));
        Assert.Equal([booked[0]], departures.Items.Select(item => item.Id));
        Assert.Equal(3, arrivals.TotalCount);
        Assert.Equal(2, arrivals.TotalPages);
    }

    [Fact]
    public async Task AWindowThatRunsToTheLastRepresentableDayIsAnswered()
    {
        var (_, slot) = await workspace.ATermAsync(capacity: 10, startsAt: TermStart);
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 2);

        var page = await workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest { From = TermDay, To = DateOnly.MaxValue });

        Assert.Equal([booked.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task AWindowThatEndsBeforeItStartsIsRefused()
    {
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.ListAsync(
            guest,
            RoleNames.Guest,
            new ReservationSearchRequest { From = Soon, To = Soon.AddDays(-1) }));
    }
}
