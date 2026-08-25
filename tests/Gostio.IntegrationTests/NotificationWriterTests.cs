using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Model.Validation;
using Gostio.Services.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class NotificationWriterTests(DatabaseFixture fixture)
{
    private static readonly DateTime Raised = new(2026, 6, 1, 9, 30, 0, DateTimeKind.Utc);

    [Fact]
    public async Task AMessageBecomesAnUnreadNotification()
    {
        var userId = await fixture.AddUserAsync("the-password");

        await WriteAsync(new NotificationMessage
        {
            UserId = userId,
            Type = NotificationType.HostVerificationDecided,
            Title = "You are a host",
            Body = "Your request to host was accepted.",
            CreatedAt = Raised,
        });

        var written = Assert.Single(await NotificationsOfAsync(userId));

        Assert.Equal(NotificationType.HostVerificationDecided, written.Type);
        Assert.Equal("You are a host", written.Title);
        Assert.Equal("Your request to host was accepted.", written.Body);
        Assert.Equal(Raised, written.CreatedAt);
        Assert.Null(written.ReadAt);
        Assert.Null(written.ReservationId);
    }

    // One character over would fail every attempt and lose the notice.
    [Fact]
    public async Task TextTooLongForItsColumnIsCutRatherThanLost()
    {
        var userId = await fixture.AddUserAsync("the-password");

        await WriteAsync(new NotificationMessage
        {
            UserId = userId,
            Type = NotificationType.HostVerificationDecided,
            Title = new string('t', ColumnLengths.Title + 40),
            Body = new string('b', ColumnLengths.NotificationBody + 40),
            CreatedAt = Raised,
        });

        var written = Assert.Single(await NotificationsOfAsync(userId));

        Assert.Equal(ColumnLengths.Title, written.Title.Length);
        Assert.Equal(ColumnLengths.NotificationBody, written.Body.Length);
    }

    // At least once, so a redelivery writes a second row.
    [Fact]
    public async Task AMessageDeliveredTwiceIsWrittenTwice()
    {
        var userId = await fixture.AddUserAsync("the-password");

        var message = new NotificationMessage
        {
            UserId = userId,
            Type = NotificationType.HostVerificationDecided,
            Title = "Twice",
            Body = "The same notice arrived again.",
            CreatedAt = Raised,
        };

        await WriteAsync(message);
        await WriteAsync(message);

        Assert.Equal(2, (await NotificationsOfAsync(userId)).Count);
    }

    // A message naming nobody fails, which is what the consumer retries.
    [Fact]
    public async Task AMessageForAnAccountThatDoesNotExistFails()
    {
        var message = new NotificationMessage
        {
            UserId = int.MaxValue,
            Type = NotificationType.HostVerificationDecided,
            Title = "Nobody",
            Body = "There is no such account.",
            CreatedAt = Raised,
        };

        await Assert.ThrowsAsync<DbUpdateException>(() => WriteAsync(message));
    }

    private async Task WriteAsync(NotificationMessage message)
    {
        await using var provider = fixture.BuildConsumers();
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider
            .GetRequiredService<INotificationWriter>()
            .WriteAsync(message, default);
    }

    private async Task<List<NotificationRow>> NotificationsOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.Notifications
            .AsNoTracking()
            .Where(notification => notification.UserId == userId)
            .OrderBy(notification => notification.Id)
            .Select(notification => new NotificationRow(
                notification.Type,
                notification.ReservationId,
                notification.Title,
                notification.Body,
                notification.ReadAt,
                notification.CreatedAt))
            .ToListAsync();
    }

    private sealed record NotificationRow(
        NotificationType Type,
        int? ReservationId,
        string Title,
        string Body,
        DateTime? ReadAt,
        DateTime CreatedAt);
}
