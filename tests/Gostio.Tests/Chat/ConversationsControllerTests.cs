using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Chat;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Chat;

// No role separates these: membership is the gate, and it is the service that
// holds it.
public sealed class ConversationsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/conversations";

    private readonly StubConversations conversations = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IConversationService>(conversations));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task TheInboxIsOpenToAnySignedInAccount(string role)
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheInboxCarriesItsFiltersThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?type=Support&reservationId=4&withUserId=9&pageSize=5",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(ConversationType.Support, conversations.LastSearch?.Type);
        Assert.Equal(4, conversations.LastSearch?.ReservationId);
        Assert.Equal(9, conversations.LastSearch?.WithUserId);
        Assert.Equal(5, conversations.LastSearch?.PageSize);
    }

    [Fact]
    public async Task ReadingOneNamesTheOneItWasAskedFor()
    {
        var response = await host.SendAsync(HttpMethod.Get, $"{Route}/8", RoleNames.Host);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(8, conversations.LastRead);
    }

    // Opening a thread that already stands answers with it rather than refusing,
    // so the route reads as a find-or-create and still says where to read it.
    [Fact]
    public async Task OpeningAThreadAnswersWithWhereToReadIt()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Guest,
            new ConversationOpenRequest { WithUserId = 12 });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal($"{Route}/1", response.Headers.Location?.AbsolutePath);
        Assert.Equal(12, conversations.LastOpened?.WithUserId);
        Assert.Null(conversations.LastOpened?.ReservationId);
    }

    [Fact]
    public async Task AThreadAboutABookingNamesTheBookingRatherThanTheAccount()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Guest,
            new ConversationOpenRequest { ReservationId = 31 });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal(31, conversations.LastOpened?.ReservationId);
        Assert.Null(conversations.LastOpened?.WithUserId);
    }

    [Fact]
    public async Task SupportIsARouteOfItsOwnAndTakesNoBody()
    {
        var response = await host.SendAsync(HttpMethod.Post, $"{Route}/support", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.True(conversations.OpenedSupport);
        Assert.Null(conversations.LastOpened);
    }

    [Theory]
    [InlineData("GET", Route)]
    [InlineData("GET", $"{Route}/8")]
    [InlineData("POST", Route)]
    [InlineData("POST", $"{Route}/support")]
    public async Task NoneOfItIsReachableWithoutAToken(string method, string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static ConversationResponse Thread(int id) => new()
    {
        Id = id,
        Type = nameof(ConversationType.Direct),
        ReservationId = null,
        ListingTitle = null,
        Participants = [],
        CreatedAt = new DateTime(2026, 8, 25, 9, 0, 0, DateTimeKind.Utc),
        LastActivityAt = new DateTime(2026, 8, 25, 9, 0, 0, DateTimeKind.Utc),
    };

    private sealed class StubConversations : IConversationService
    {
        public ConversationSearchRequest? LastSearch { get; private set; }

        public ConversationOpenRequest? LastOpened { get; private set; }

        public bool OpenedSupport { get; private set; }

        public int? LastRead { get; private set; }

        public Task<PagedResult<ConversationResponse>> SearchAsync(
            ConversationSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<ConversationResponse>
            {
                Items = [Thread(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<ConversationResponse> GetAsync(
            int conversationId,
            CancellationToken cancellationToken)
        {
            LastRead = conversationId;

            return Task.FromResult(Thread(conversationId));
        }

        public Task<ConversationResponse> OpenAsync(
            ConversationOpenRequest request,
            CancellationToken cancellationToken)
        {
            LastOpened = request;

            return Task.FromResult(Thread(1));
        }

        public Task<ConversationResponse> OpenSupportAsync(CancellationToken cancellationToken)
        {
            OpenedSupport = true;

            return Task.FromResult(Thread(1));
        }
    }
}
