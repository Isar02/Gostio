using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Model.Requests;
using Gostio.Services.Messaging;
using Gostio.Services.Notifications;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// The row is the record and the push is a delivery of it. They are raised
// together and read apart, so a phone that never hears about a booking still
// finds it in the list.
[Collection(DatabaseCollection.Name)]
public class PushDeliveryTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-push";

    private static readonly DateTime Raised = new(2026, 6, 1, 9, 30, 0, DateTimeKind.Utc);

    private readonly ReservationWorkspace workspace = new(fixture);

    [Fact]
    public async Task ABookingRaisesTheRowAndThePushTogether()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(60));

        var (_, notices) = await workspace.WatchedAsync(
            guest,
            RoleNames.Guest,
            (IReservationService service) => service.CreateAsync(
                new ReservationCreateRequest
                {
                    AccommodationId = listing,
                    CheckInDate = checkIn,
                    CheckOutDate = checkIn.AddDays(2),
                    GuestCount = 2,
                },
                default));

        var rows = notices.Of<NotificationMessage>().ToList();
        var pushes = notices.Of<PushMessage>().ToList();

        Assert.NotEmpty(rows);
        Assert.Equal(rows.Count, pushes.Count);
        Assert.Equal(
            rows.Select(row => (row.UserId, row.Title, row.Body)).ToArray(),
            pushes.Select(push => (push.UserId, push.Title, push.Body)).ToArray());
    }

    [Fact]
    public async Task APushGoesToEveryDeviceTheAccountRegistered()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var sender = new FakePushSender();

        await RegisterAsync(userId, "device-one");
        await RegisterAsync(userId, "device-two");

        await DeliverAsync(sender, PushFor(userId));

        Assert.Equal(["device-one", "device-two"], sender.Sent.Order());
    }

    [Fact]
    public async Task ANoticeReachesNobodyElsesDevices()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var other = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var sender = new FakePushSender();

        await RegisterAsync(userId, "device-of-the-owner");
        await RegisterAsync(other, "device-of-somebody-else");

        await DeliverAsync(sender, PushFor(userId));

        Assert.Equal(["device-of-the-owner"], sender.Sent);
    }

    // Applications are uninstalled, and a row that is guaranteed to fail is one
    // the table should not keep.
    [Fact]
    public async Task ADeviceTheServiceNoLongerKnowsIsForgotten()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var sender = new FakePushSender { Answer = PushDelivery.Unregistered };

        await RegisterAsync(userId, "device-that-was-uninstalled");

        await DeliverAsync(sender, PushFor(userId));

        Assert.Empty(await TokensOfAsync(userId));
    }

    // An account signed in on a phone and a tablet: the one that cannot be
    // reached is not the other's business, on this pass or on any retry of it.
    [Fact]
    public async Task ADeviceThatCannotBeReachedDoesNotHoldUpTheOthers()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var sender = new FakePushSender
        {
            Refuses = new HashSet<string> { "device-in-the-middle" },
        };

        await RegisterAsync(userId, "device-before-it");
        await RegisterAsync(userId, "device-in-the-middle");
        await RegisterAsync(userId, "device-after-it");

        await Assert.ThrowsAsync<AggregateException>(
            () => DeliverAsync(sender, PushFor(userId)));

        Assert.Equal(["device-after-it", "device-before-it"], sender.Sent.Order());
    }

    // The one failure that is about the deployment rather than about a device,
    // and the queue has to see it as it is or it retries five times over.
    [Fact]
    public async Task AFailureThatNoRetryWouldFixIsHandedOnUnchanged()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var sender = new FakePushSender
        {
            Throws = new PermanentMessageFailure("There is no service account."),
        };

        await RegisterAsync(userId, "device-behind-a-missing-credential");

        await Assert.ThrowsAsync<PermanentMessageFailure>(
            () => DeliverAsync(sender, PushFor(userId)));

        Assert.Single(await TokensOfAsync(userId));
    }
    [Fact]
    public async Task ADeliveryThatFailsLeavesTheNotificationRowWhereItIs()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var notice = NoticeFor(userId);

        await RegisterAsync(userId, "device-behind-a-broken-service");

        await using var provider = fixture.BuildConsumers(new FakePushSender
        {
            Refuses = new HashSet<string> { "device-behind-a-broken-service" },
        });
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider
            .GetRequiredService<INotificationWriter>()
            .WriteAsync(notice, default);

        await Assert.ThrowsAsync<AggregateException>(() =>
            scope.ServiceProvider
                .GetRequiredService<IPushDispatcher>()
                .DeliverAsync(PushMessage.Of(notice), default));

        await using var db = fixture.CreateContext();

        Assert.True(await db.Notifications.AnyAsync(row => row.UserId == userId));
        Assert.Single(await TokensOfAsync(userId));
    }

    private static PushMessage PushFor(int userId) => PushMessage.Of(NoticeFor(userId));

    private static NotificationMessage NoticeFor(int userId) => new()
    {
        UserId = userId,
        Type = NotificationType.HostVerificationDecided,
        Title = "You are a host",
        Body = "Your request to host was accepted.",
        CreatedAt = Raised,
    };

    private async Task DeliverAsync(IPushSender sender, PushMessage message)
    {
        await using var provider = fixture.BuildConsumers(sender);
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider
            .GetRequiredService<IPushDispatcher>()
            .DeliverAsync(message, default);
    }

    private async Task RegisterAsync(int userId, string token)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(userId, RoleNames.Guest));

        await services
            .GetRequiredService<IDeviceTokenService>()
            .RegisterAsync(
                new DeviceTokenRequest { Token = token, Platform = DevicePlatform.Android },
                default);
    }

    private async Task<List<string>> TokensOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.DeviceTokens
            .AsNoTracking()
            .Where(device => device.UserId == userId)
            .Select(device => device.Token)
            .ToListAsync();
    }

    private sealed class FakePushSender : IPushSender
    {
        private readonly List<string> sent = [];

        public IReadOnlyList<string> Sent => sent;

        public PushDelivery Answer { get; init; } = PushDelivery.Delivered;

        public IReadOnlySet<string> Refuses { get; init; } = new HashSet<string>();

        public Exception? Throws { get; init; }

        public Task<PushDelivery> SendAsync(
            string token,
            PushMessage message,
            CancellationToken cancellationToken)
        {
            if (Throws is Exception everywhere)
            {
                throw everywhere;
            }

            if (Refuses.Contains(token))
            {
                throw new InvalidOperationException($"{token} could not be reached.");
            }

            sent.Add(token);

            return Task.FromResult(Answer);
        }
    }
}
