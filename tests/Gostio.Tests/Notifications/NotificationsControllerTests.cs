using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Notifications;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Notifications;

// No role separates these: the owner is the token, not the path.
public sealed class NotificationsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/notifications";

    private readonly StubNotifications notifications = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<INotificationService>(notifications));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task TheListIsOpenToAnySignedInAccount(string role)
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheListCarriesItsFiltersThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?isRead=false&type=PaymentSucceeded&pageSize=5",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.False(notifications.LastSearch?.IsRead);
        Assert.Equal(NotificationType.PaymentSucceeded, notifications.LastSearch?.Type);
        Assert.Equal(5, notifications.LastSearch?.PageSize);
    }

    [Fact]
    public async Task TheCountIsItsOwnRouteRatherThanAPageOfRows()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}/unread-count", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Null(notifications.LastSearch);
    }

    [Fact]
    public async Task MarkingOneReadNamesTheOneItWasAskedFor()
    {
        var response = await host.SendAsync(HttpMethod.Post, $"{Route}/7/read", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(7, notifications.LastMarked);
    }

    [Fact]
    public async Task MarkingThemAllReadIsARouteOfItsOwn()
    {
        var response = await host.SendAsync(HttpMethod.Post, $"{Route}/read", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(notifications.MarkedAll);
        Assert.Null(notifications.LastMarked);
    }

    [Theory]
    [InlineData("GET", Route)]
    [InlineData("GET", $"{Route}/unread-count")]
    [InlineData("POST", $"{Route}/7/read")]
    [InlineData("POST", $"{Route}/read")]
    public async Task NoneOfItIsReachableWithoutAToken(string method, string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static NotificationResponse Row(int id) => new()
    {
        Id = id,
        Type = nameof(NotificationType.ReservationCreated),
        ReservationId = 3,
        Title = "Your booking is waiting for the host",
        Body = "The host has to confirm it before the hold runs out.",
        IsRead = false,
        CreatedAt = new DateTime(2026, 8, 24, 12, 0, 0, DateTimeKind.Utc),
    };

    private sealed class StubNotifications : INotificationService
    {
        public NotificationSearchRequest? LastSearch { get; private set; }

        public int? LastMarked { get; private set; }

        public bool MarkedAll { get; private set; }

        public Task<PagedResult<NotificationResponse>> SearchAsync(
            NotificationSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<NotificationResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<UnreadCountResponse> UnreadAsync(CancellationToken cancellationToken) =>
            Task.FromResult(new UnreadCountResponse { Unread = 2 });

        public Task<NotificationResponse> MarkReadAsync(
            int notificationId,
            CancellationToken cancellationToken)
        {
            LastMarked = notificationId;

            return Task.FromResult(Row(notificationId));
        }

        public Task<UnreadCountResponse> MarkAllReadAsync(CancellationToken cancellationToken)
        {
            MarkedAll = true;

            return Task.FromResult(new UnreadCountResponse { Unread = 0 });
        }
    }
}
