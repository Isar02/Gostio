using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ConversationTests(DatabaseFixture fixture)
{
    private readonly ConversationWorkspace workspace = new(fixture);

    [Fact]
    public async Task AThreadReadsBackWithTheAccountsInIt()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();

        var thread = await workspace.ADirectThreadAsync(guest, host);
        var read = await workspace.ReadAsync(guest, RoleNames.Guest, thread);

        Assert.Equal(nameof(ConversationType.Direct), read.Type);
        Assert.Null(read.ReservationId);
        Assert.Null(read.ListingTitle);
        Assert.Equal(
            [.. new[] { guest, host }.Order()],
            [.. read.Participants.Select(who => who.UserId).Order()]);
        Assert.All(read.Participants, who => Assert.Null(who.LastReadAt));
        Assert.All(read.Participants, who => Assert.NotEmpty(who.Username));
        Assert.Equal(read.CreatedAt, read.LastActivityAt);
    }

    [Fact]
    public async Task AThreadAboutABookingNamesWhatWasBooked()
    {
        var booking = await workspace.ABookingAsync();

        var thread = await workspace.AThreadAboutAsync(
            booking.Reservation, booking.Guest, booking.Host);

        var read = await workspace.ReadAsync(booking.Host, RoleNames.Host, thread);

        Assert.Equal(booking.Reservation, read.ReservationId);
        Assert.NotNull(read.ListingTitle);
    }

    [Fact]
    public async Task ToSomebodyOutsideItAThreadDoesNotExist()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var stranger = await workspace.AGuestAsync();

        var thread = await workspace.ADirectThreadAsync(guest, host);

        Assert.Equal(thread, (await workspace.ReadAsync(guest, RoleNames.Guest, thread)).Id);
        Assert.Equal(thread, (await workspace.ReadAsync(host, RoleNames.Host, thread)).Id);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stranger, RoleNames.Guest, thread));
    }

    [Fact]
    public async Task AnAdministratorOutsideADirectThreadReachesItNoMoreThanAnybodyElse()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var administrator = await workspace.AnAdministratorAsync();

        var thread = await workspace.ADirectThreadAsync(guest, host);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(administrator, RoleNames.Administrator, thread));
    }

    [Fact]
    public async Task EveryAdministratorReachesASupportThreadNobodyPickedThemFor()
    {
        var guest = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var somebodyElse = await workspace.AGuestAsync();

        var thread = await workspace.ASupportThreadAsync(guest);
        var read = await workspace.ReadAsync(administrator, RoleNames.Administrator, thread);

        Assert.Equal(thread, read.Id);
        Assert.Equal(nameof(ConversationType.Support), read.Type);
        Assert.Equal(guest, Assert.Single(read.Participants).UserId);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(somebodyElse, RoleNames.Guest, thread));
    }

    [Fact]
    public async Task NothingASearchNamesWidensWhatACallerSees()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var stranger = await workspace.AGuestAsync();

        var mine = await workspace.ADirectThreadAsync(guest, host);
        var theirs = await workspace.ADirectThreadAsync(stranger, host);

        var asked = await workspace.SearchAsync(
            guest, RoleNames.Guest, new ConversationSearchRequest { WithUserId = stranger });

        Assert.Empty(asked.Items);

        var own = await workspace.SearchAsync(guest, RoleNames.Guest);

        Assert.Equal(mine, Assert.Single(own.Items).Id);

        var hosts = await workspace.SearchAsync(
            host, RoleNames.Host, new ConversationSearchRequest { PageSize = 100 });

        Assert.Contains(hosts.Items, thread => thread.Id == mine);
        Assert.Contains(hosts.Items, thread => thread.Id == theirs);
    }

    [Fact]
    public async Task AnInboxIsNarrowedByTheBookingAndByTheType()
    {
        var booking = await workspace.ABookingAsync();

        var aboutIt = await workspace.AThreadAboutAsync(
            booking.Reservation, booking.Guest, booking.Host);

        await workspace.ASupportThreadAsync(booking.Guest);

        var found = await workspace.SearchAsync(
            booking.Guest,
            RoleNames.Guest,
            new ConversationSearchRequest { ReservationId = booking.Reservation });

        Assert.Equal(aboutIt, Assert.Single(found.Items).Id);

        var support = await workspace.SearchAsync(
            booking.Guest,
            RoleNames.Guest,
            new ConversationSearchRequest { Type = ConversationType.Support });

        Assert.Equal(
            nameof(ConversationType.Support), Assert.Single(support.Items).Type);
    }

    [Fact]
    public async Task TheInboxLeadsWithWhateverWasSaidLast()
    {
        var host = await workspace.AHostAsync();
        var first = await workspace.AGuestAsync();
        var second = await workspace.AGuestAsync();

        var older = await workspace.ADirectThreadAsync(first, host);
        var newer = await workspace.ADirectThreadAsync(second, host);
        var spoken = DateTime.UtcNow.AddMinutes(5);

        await workspace.SayAsync(older, first, "Is the cottage still free in May?", spoken);

        var inbox = await workspace.SearchAsync(
            host, RoleNames.Host, new ConversationSearchRequest { PageSize = 100 });

        var ordered = inbox.Items.Where(thread => thread.Id == older || thread.Id == newer);

        Assert.Equal(older, ordered.First().Id);
        Assert.Equal(spoken, ordered.First().LastActivityAt, TimeSpan.FromSeconds(1));
        Assert.Equal(newer, ordered.Last().Id);
    }
}
