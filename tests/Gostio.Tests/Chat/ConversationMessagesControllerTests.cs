using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Chat;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Chat;

public sealed class ConversationMessagesControllerTests : IAsyncLifetime
{
    private const string Route = "/api/conversations";

    private readonly StubMessages messages = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IMessageService>(messages));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task AThreadIsReadAndWrittenByAnySignedInAccount(string role)
    {
        var read = await host.SendAsync(HttpMethod.Get, $"{Route}/3/messages", role);

        var written = await host.SendAsync(
            HttpMethod.Post,
            $"{Route}/3/messages",
            role,
            new MessageSendRequest { Body = "Anything." });

        Assert.Equal(HttpStatusCode.OK, read.StatusCode);
        Assert.Equal(HttpStatusCode.OK, written.StatusCode);
    }

    [Fact]
    public async Task ThePageIsBoundedTheWayEveryOtherListIs()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}/3/messages?page=2&pageSize=500", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, messages.LastConversation);
        Assert.Equal(2, messages.LastPaging?.Page);
        Assert.Equal(PagedRequest.MaxPageSize, messages.LastPaging?.PageSize);
    }

    [Fact]
    public async Task ASentMessageCarriesItsBodyThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            $"{Route}/9/messages",
            RoleNames.Host,
            new MessageSendRequest { Body = "The code is on the door." });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(9, messages.LastConversation);
        Assert.Equal("The code is on the door.", messages.LastBody);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task ABlankBodyIsRefusedBeforeItReachesTheService(string? body)
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            $"{Route}/9/messages",
            RoleNames.Guest,
            new MessageSendRequest { Body = body });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(messages.LastBody);
    }

    [Fact]
    public async Task ABodyLongerThanTheColumnIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            $"{Route}/9/messages",
            RoleNames.Guest,
            new MessageSendRequest { Body = new string('x', ColumnLengths.MessageBody + 1) });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(messages.LastBody);
    }

    [Fact]
    public async Task MarkingAThreadReadNamesTheOneItWasAskedFor()
    {
        var response = await host.SendAsync(HttpMethod.Post, $"{Route}/6/read", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(6, messages.LastMarked);
    }

    [Fact]
    public async Task TheBadgeIsARouteOfItsOwnRatherThanAPageOfThreads()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}/unread-count", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Null(messages.LastConversation);
    }

    [Theory]
    [InlineData("GET", $"{Route}/3/messages")]
    [InlineData("POST", $"{Route}/3/messages")]
    [InlineData("POST", $"{Route}/3/read")]
    [InlineData("GET", $"{Route}/unread-count")]
    public async Task NoneOfItIsReachableWithoutAToken(string method, string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static MessageResponse Written(int conversationId) => new()
    {
        Id = 1,
        ConversationId = conversationId,
        SenderUserId = 42,
        SenderName = "Integration Tests",
        Body = "Anything.",
        SentAt = new DateTime(2026, 8, 25, 10, 0, 0, DateTimeKind.Utc),
    };

    private sealed class StubMessages : IMessageService
    {
        public int? LastConversation { get; private set; }

        public PagedRequest? LastPaging { get; private set; }

        public string? LastBody { get; private set; }

        public int? LastMarked { get; private set; }

        public Task<PagedResult<MessageResponse>> SearchAsync(
            int conversationId,
            PagedRequest paging,
            CancellationToken cancellationToken)
        {
            LastConversation = conversationId;
            LastPaging = paging;

            return Task.FromResult(new PagedResult<MessageResponse>
            {
                Items = [Written(conversationId)],
                Page = paging.Page,
                PageSize = paging.PageSize,
                TotalCount = 1,
            });
        }

        public Task<MessageResponse> SendAsync(
            int conversationId,
            MessageSendRequest request,
            CancellationToken cancellationToken)
        {
            LastConversation = conversationId;
            LastBody = request.Body;

            return Task.FromResult(Written(conversationId));
        }

        public Task<UnreadCountResponse> MarkReadAsync(
            int conversationId,
            CancellationToken cancellationToken)
        {
            LastMarked = conversationId;

            return Task.FromResult(new UnreadCountResponse { Unread = 0 });
        }

        public Task<UnreadCountResponse> UnreadAsync(CancellationToken cancellationToken) =>
            Task.FromResult(new UnreadCountResponse { Unread = 4 });
    }
}
