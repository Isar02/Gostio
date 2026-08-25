using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ConversationOpeningTests(DatabaseFixture fixture)
{
    private readonly ConversationWorkspace workspace = new(fixture);

    [Fact]
    public async Task AnEnquiryPutsTheTwoOfThemInAThread()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();

        var opened = await workspace.OpenWithAsync(guest, RoleNames.Guest, host);

        Assert.Equal(nameof(ConversationType.Direct), opened.Type);
        Assert.Null(opened.ReservationId);
        Assert.Equal(
            [.. new[] { guest, host }.Order()],
            [.. opened.Participants.Select(who => who.UserId).Order()]);
        Assert.Equal(opened.CreatedAt, opened.LastActivityAt);
    }

    [Fact]
    public async Task AskingForTheSameEnquiryTwiceAnswersWithTheOneThatStands()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();

        var first = await workspace.OpenWithAsync(guest, RoleNames.Guest, host);
        var again = await workspace.OpenWithAsync(guest, RoleNames.Guest, host);
        var fromTheOtherSide = await workspace.OpenWithAsync(host, RoleNames.Host, guest);

        Assert.Equal(first.Id, again.Id);
        Assert.Equal(first.Id, fromTheOtherSide.Id);
        Assert.Equal(1, await workspace.ThreadsBetweenAsync(guest, host));
    }

    [Fact]
    public async Task AnEnquiryGoesToAnAccountThatHostsAndToNobodyElse()
    {
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.OpenWithAsync(guest, RoleNames.Guest, somebodyElse));
    }

    [Fact]
    public async Task AThreadNeedsSomebodyElseInIt()
    {
        var host = await workspace.AHostAsync();

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.OpenWithAsync(host, RoleNames.Host, host));
    }

    [Fact]
    public async Task AThreadIsAboutABookingOrWithAnAccountAndNeverBoth()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var booking = await workspace.ABookingAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.OpenAsync(
            guest,
            RoleNames.Guest,
            new ConversationOpenRequest
            {
                WithUserId = host,
                ReservationId = booking.Reservation,
            }));

        await Assert.ThrowsAsync<ValidationException>(() => workspace.OpenAsync(
            guest, RoleNames.Guest, new ConversationOpenRequest()));
    }

    [Fact]
    public async Task AThreadAboutABookingHoldsItsGuestAndItsHost()
    {
        var booking = await workspace.ABookingAsync();

        var opened = await workspace.OpenAboutAsync(
            booking.Guest, RoleNames.Guest, booking.Reservation);

        Assert.Equal(booking.Reservation, opened.ReservationId);
        Assert.NotNull(opened.ListingTitle);
        Assert.Equal(
            [.. new[] { booking.Guest, booking.Host }.Order()],
            [.. opened.Participants.Select(who => who.UserId).Order()]);
    }

    [Fact]
    public async Task OneBookingHasOneThreadWhicheverSideAsksForIt()
    {
        var booking = await workspace.ABookingAsync();

        var byTheGuest = await workspace.OpenAboutAsync(
            booking.Guest, RoleNames.Guest, booking.Reservation);
        var byTheHost = await workspace.OpenAboutAsync(
            booking.Host, RoleNames.Host, booking.Reservation);

        Assert.Equal(byTheGuest.Id, byTheHost.Id);
    }

    [Fact]
    public async Task ToAStrangerTheBookingHasNoThreadToOpen()
    {
        var booking = await workspace.ABookingAsync();
        var stranger = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.OpenAboutAsync(stranger, RoleNames.Guest, booking.Reservation));
    }

    [Fact]
    public async Task TwoTapsOfTheSameEnquiryOpenOneThread()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();

        var opened = await workspace.OpenedAtOnceAsync(guest, host);

        Assert.Equal(opened[0], opened[1]);
        Assert.Equal(1, await workspace.ThreadsBetweenAsync(guest, host));
    }

    [Fact]
    public async Task SupportOpensOneThreadPerAccountAndNamesNobodyToAnswerIt()
    {
        var guest = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();

        var opened = await workspace.OpenSupportAsync(guest, RoleNames.Guest);
        var again = await workspace.OpenSupportAsync(guest, RoleNames.Guest);

        Assert.Equal(nameof(ConversationType.Support), opened.Type);
        Assert.Null(opened.ReservationId);
        Assert.Equal(opened.Id, again.Id);
        Assert.Equal([guest], await workspace.ParticipantsOfAsync(opened.Id));
        Assert.Equal(
            opened.Id,
            (await workspace.ReadAsync(administrator, RoleNames.Administrator, opened.Id)).Id);
    }

    [Fact]
    public async Task AFormerAdministratorOpensTheirOwnSupportThread()
    {
        var guest = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var guestsThread = await workspace.ASupportThreadAsync(guest);

        await workspace.SendAsync(
            administrator, RoleNames.Administrator, guestsThread, "I will look into this.");
        await workspace.ReplaceRoleAsync(administrator, RoleNames.Guest);

        var opened = await workspace.OpenSupportAsync(administrator, RoleNames.Guest);

        Assert.NotEqual(guestsThread, opened.Id);
        Assert.Equal([administrator], await workspace.ParticipantsOfAsync(opened.Id));
        Assert.Equal(
            opened.Id,
            (await workspace.OpenSupportAsync(administrator, RoleNames.Guest)).Id);
    }

    [Fact]
    public async Task SupportIsAnsweredFromAnAdministratorRatherThanAskedOfIt()
    {
        var administrator = await workspace.AnAdministratorAsync();

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.OpenSupportAsync(administrator, RoleNames.Administrator));
    }
}
