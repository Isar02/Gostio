using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ConversationMessageTests(DatabaseFixture fixture)
{
    private readonly ConversationWorkspace workspace = new(fixture);

    [Fact]
    public async Task AMessageReadsBackWithWhoWroteIt()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        var sent = await workspace.SendAsync(
            guest, RoleNames.Guest, thread, "  Is the terrace covered?  ");

        Assert.Equal(thread, sent.ConversationId);
        Assert.Equal(guest, sent.SenderUserId);
        Assert.Equal("Is the terrace covered?", sent.Body);
        Assert.NotEmpty(sent.SenderName);
        Assert.NotEqual(default, sent.SentAt);
    }

    [Fact]
    public async Task ABlankMessageIsNotAMessage()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.SendAsync(guest, RoleNames.Guest, thread, "   "));
    }

    [Fact]
    public async Task ToSomebodyOutsideItTheThreadHasNoMessagesToReadOrWrite()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var stranger = await workspace.AGuestAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        await workspace.SendAsync(guest, RoleNames.Guest, thread, "Are the dates still open?");

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.MessagesAsync(stranger, RoleNames.Guest, thread));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.SendAsync(stranger, RoleNames.Guest, thread, "Let me in."));
    }

    [Fact]
    public async Task MessagesStayBehindMembershipWhenItMovesBeforeTheRead()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        await workspace.SendAsync(host, RoleNames.Host, thread, "This stays in the thread.");

        var moved = new RaceInterceptor(
            "[Messages] AS [m]",
            () => workspace.RemoveParticipantAsync(thread, guest));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.MessagesAsync(guest, RoleNames.Guest, thread, paging: null, moved));

        Assert.True(moved.Fired);
    }

    [Fact]
    public async Task AThreadIsPagedFromItsEndBackwards()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        await workspace.SendAsync(guest, RoleNames.Guest, thread, "First.");
        await workspace.SendAsync(host, RoleNames.Host, thread, "Second.");
        var last = await workspace.SendAsync(guest, RoleNames.Guest, thread, "Third.");

        var page = await workspace.MessagesAsync(
            guest, RoleNames.Guest, thread, new PagedRequest { PageSize = 2 });

        Assert.Equal(3, page.TotalCount);
        Assert.Equal(2, page.Items.Count);
        Assert.Equal(last.Id, page.Items[0].Id);
        Assert.Equal("Second.", page.Items[1].Body);
    }

    [Fact]
    public async Task UnreadCountsWhatTheOtherSideSaidAndNeverYourOwn()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        await workspace.SendAsync(guest, RoleNames.Guest, thread, "Two questions, if I may.");
        await workspace.SendAsync(host, RoleNames.Host, thread, "Go ahead.");
        await workspace.SendAsync(host, RoleNames.Host, thread, "I am here all evening.");

        Assert.Equal(2, (await workspace.UnreadAsync(guest, RoleNames.Guest)).Unread);
        Assert.Equal(1, (await workspace.UnreadAsync(host, RoleNames.Host)).Unread);

        var row = Assert.Single((await workspace.SearchAsync(guest, RoleNames.Guest)).Items);

        Assert.Equal(thread, row.Id);
        Assert.Equal(2, row.UnreadCount);
        Assert.Equal("I am here all evening.", row.LastMessage?.Body);
        Assert.Equal(host, row.LastMessage?.SenderUserId);
    }

    [Fact]
    public async Task MarkingAThreadReadClearsWhatItWasHolding()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        await workspace.SendAsync(host, RoleNames.Host, thread, "The key box code is 4417.");

        Assert.Equal(1, (await workspace.UnreadAsync(guest, RoleNames.Guest)).Unread);

        var cleared = await workspace.MarkReadAsync(guest, RoleNames.Guest, thread);

        Assert.Equal(0, cleared.Unread);
        Assert.Equal(0, (await workspace.ReadAsync(guest, RoleNames.Guest, thread)).UnreadCount);

        await workspace.SendAsync(host, RoleNames.Host, thread, "One more thing.");

        Assert.Equal(1, (await workspace.UnreadAsync(guest, RoleNames.Guest)).Unread);
    }

    [Fact]
    public async Task TheBadgeAgreesWithTheRowsBeneathIt()
    {
        var host = await workspace.AHostAsync();
        var first = await workspace.AGuestAsync();
        var second = await workspace.AGuestAsync();
        var one = await workspace.ADirectThreadAsync(first, host);
        var two = await workspace.ADirectThreadAsync(second, host);

        await workspace.SendAsync(first, RoleNames.Guest, one, "Is late arrival all right?");
        await workspace.SendAsync(second, RoleNames.Guest, two, "Do you have a cot?");
        await workspace.SendAsync(second, RoleNames.Guest, two, "For a one-year-old.");

        var inbox = await workspace.SearchAsync(
            host, RoleNames.Host, new ConversationSearchRequest { PageSize = 100 });

        var badge = await workspace.UnreadAsync(host, RoleNames.Host);

        Assert.Equal(inbox.Items.Sum(thread => thread.UnreadCount), badge.Unread);
        Assert.Equal(3, badge.Unread);
    }

    [Fact]
    public async Task AnsweringASupportThreadIsWhatPutsAnAdministratorInIt()
    {
        var guest = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var thread = await workspace.ASupportThreadAsync(guest);

        await workspace.SendAsync(guest, RoleNames.Guest, thread, "My refund has not arrived.");

        Assert.Equal([guest], await workspace.ParticipantsOfAsync(thread));

        await workspace.SendAsync(
            administrator, RoleNames.Administrator, thread, "It left us on Tuesday.");

        Assert.Equal(
            [.. new[] { guest, administrator }.Order()],
            await workspace.ParticipantsOfAsync(thread));

        var read = await workspace.ReadAsync(guest, RoleNames.Guest, thread);

        Assert.Equal(1, read.UnreadCount);
        Assert.Equal(administrator, read.LastMessage?.SenderUserId);
    }
}
