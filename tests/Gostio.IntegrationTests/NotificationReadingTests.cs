using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Messaging;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Messaging;
using Gostio.Services.Notifications;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class NotificationReadingTests(DatabaseFixture fixture)
{
    [Fact]
    public async Task AListShowsOnlyWhatWasRaisedForTheCaller()
    {
        var mine = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);
        var theirs = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);

        await RaiseAsync(mine, "Mine");
        await RaiseAsync(theirs, "Theirs");

        var listed = await SearchAsync(mine, new NotificationSearchRequest());

        Assert.Equal(["Mine"], listed.Items.Select(row => row.Title));
    }

    // No reading somebody's notifications over their shoulder.
    [Fact]
    public async Task AnAdministratorSeesTheirOwnAndNobodyElsesEither()
    {
        var somebody = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);
        var administrator = await fixture.AddUserAsync(
            ReservationWorkspace.Password, RoleNames.Administrator);

        var raised = await RaiseAsync(somebody, "Not for an administrator");

        var listed = await SearchAsync(administrator, new NotificationSearchRequest());

        Assert.DoesNotContain(raised, listed.Items.Select(row => row.Id));

        await Assert.ThrowsAsync<NotFoundException>(
            () => MarkReadAsync(administrator, RoleNames.Administrator, raised));
    }

    [Fact]
    public async Task TheNewestOneIsTheFirstOneListed()
    {
        var userId = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);

        await RaiseAsync(userId, "Older", DateTime.UtcNow.AddHours(-2));
        await RaiseAsync(userId, "Newer", DateTime.UtcNow);

        var listed = await SearchAsync(userId, new NotificationSearchRequest());

        Assert.Equal(["Newer", "Older"], listed.Items.Select(row => row.Title));
    }

    [Fact]
    public async Task MarkingOneReadTakesItOutOfTheCountAndLeavesTheRest()
    {
        var userId = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);

        var first = await RaiseAsync(userId, "First");

        await RaiseAsync(userId, "Second");

        Assert.Equal(2, await UnreadAsync(userId));

        var marked = await MarkReadAsync(userId, RoleNames.Guest, first);

        Assert.True(marked.IsRead);
        Assert.NotNull(marked.ReadAt);
        Assert.Equal(1, await UnreadAsync(userId));
    }

    // Marked from every screen that shows it, so the first instant must hold.
    [Fact]
    public async Task MarkingOneReadTwiceKeepsTheInstantItWasFirstRead()
    {
        var userId = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);
        var raised = await RaiseAsync(userId, "Once");

        var first = await MarkReadAsync(userId, RoleNames.Guest, raised);
        var second = await MarkReadAsync(userId, RoleNames.Guest, raised);

        Assert.Equal(first.ReadAt, second.ReadAt);
        Assert.Equal(0, await UnreadAsync(userId));
    }

    [Fact]
    public async Task MarkingThemAllReadEmptiesTheCount()
    {
        var userId = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);

        await RaiseAsync(userId, "First");
        await RaiseAsync(userId, "Second");
        await RaiseAsync(userId, "Third");

        var left = await AsAsync(
            userId,
            RoleNames.Guest,
            service => service.MarkAllReadAsync(default));

        Assert.Equal(0, left.Unread);
        Assert.Equal(0, await UnreadAsync(userId));
    }

    [Fact]
    public async Task TheListNarrowsByWhetherItWasReadAndByWhatItIsAbout()
    {
        var userId = await fixture.AddUserAsync(ReservationWorkspace.Password, RoleNames.Guest);

        var read = await RaiseAsync(userId, "Read");

        await RaiseAsync(userId, "Unread");
        await MarkReadAsync(userId, RoleNames.Guest, read);

        var unread = await SearchAsync(userId, new NotificationSearchRequest { IsRead = false });

        Assert.Equal(["Unread"], unread.Items.Select(row => row.Title));

        var byType = await SearchAsync(
            userId,
            new NotificationSearchRequest { Type = NotificationType.PaymentSucceeded });

        Assert.Empty(byType.Items);
    }

    private async Task<int> RaiseAsync(int userId, string title, DateTime? at = null)
    {
        await using var provider = fixture.BuildConsumers();
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider.GetRequiredService<INotificationWriter>().WriteAsync(
            new NotificationMessage
            {
                UserId = userId,
                Type = NotificationType.HostVerificationDecided,
                Title = title,
                Body = $"The body of {title}.",
                CreatedAt = at ?? DateTime.UtcNow,
            },
            default);

        var listed = await SearchAsync(userId, new NotificationSearchRequest());

        return listed.Items.First(row => row.Title == title).Id;
    }

    private Task<PagedResult<NotificationResponse>> SearchAsync(
        int userId,
        NotificationSearchRequest search) =>
        AsAsync(userId, RoleNames.Guest, service => service.SearchAsync(search, default));

    private Task<NotificationResponse> MarkReadAsync(int userId, string role, int notificationId) =>
        AsAsync(userId, role, service => service.MarkReadAsync(notificationId, default));

    private async Task<int> UnreadAsync(int userId) =>
        (await AsAsync(userId, RoleNames.Guest, service => service.UnreadAsync(default))).Unread;

    private async Task<TResult> AsAsync<TResult>(
        int userId,
        string role,
        Func<INotificationService, Task<TResult>> work)
    {
        await using var services = fixture.BuildServices(ListingWorkspace.Caller(userId, role));

        return await work(services.GetRequiredService<INotificationService>());
    }
}
