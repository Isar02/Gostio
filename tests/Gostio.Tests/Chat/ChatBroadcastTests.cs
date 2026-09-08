using System.Security.Claims;
using Gostio.API.Hubs;
using Gostio.Model.Authorization;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;

namespace Gostio.Tests.Chat;

// The other half of ending a session: a socket already in a thread is
// delivered to without being asked anything, so the delivery is where one that
// ended elsewhere is noticed.
public sealed class ChatBroadcastTests
{
    private const int Reader = 42;

    private const int Version = 3;

    [Fact]
    public async Task AConnectionOnACurrentSessionIsLeftInTheThread()
    {
        var connections = new ChatConnections();
        var caller = Joined(connections, conversationId: 7);
        var hub = new FakeHubContext();

        await BroadcastTo(hub, connections, isCurrent: true).MessageSentAsync(
            Message(conversationId: 7), CancellationToken.None);

        Assert.False(caller.Aborted);
        Assert.Empty(hub.Groups.Removed);
        Assert.Equal(["conversation-7", "account-42"], hub.Clients.SentToGroups);
    }

    [Fact]
    public async Task AConnectionWhoseSessionEndedIsTakenOutBeforeTheMessageGoes()
    {
        var connections = new ChatConnections();
        var caller = Joined(connections, conversationId: 7);
        var hub = new FakeHubContext();

        await BroadcastTo(hub, connections, isCurrent: false).MessageSentAsync(
            Message(conversationId: 7), CancellationToken.None);

        Assert.True(caller.Aborted);
        Assert.Equal(
            [("connection-1", "conversation-7"), ("connection-1", "account-42")],
            hub.Groups.Removed);
        Assert.Empty(connections.In(7));

        // Sent either way: the closed connection is out of them by then.
        Assert.Equal(["conversation-7", "account-42"], hub.Clients.SentToGroups);
    }

    // Signing out is not the only way a session ends. The token says when it
    // stops being one, and the socket outlives that moment.
    [Fact]
    public async Task AConnectionWhoseTokenHasExpiredIsTakenOutToo()
    {
        var connections = new ChatConnections();
        var caller = Joined(
            connections,
            conversationId: 7,
            expiresAt: DateTimeOffset.UtcNow.AddMinutes(-1));

        var hub = new FakeHubContext();

        await BroadcastTo(hub, connections, isCurrent: true).MessageSentAsync(
            Message(conversationId: 7), CancellationToken.None);

        Assert.True(caller.Aborted);
        Assert.Empty(connections.In(7));
    }

    // The delivery asks about the thread it is for and the accounts in it, and
    // about nothing else.
    [Fact]
    public async Task AConnectionOutsideTheThreadAndItsAccountsIsNotTouched()
    {
        var connections = new ChatConnections();
        var caller = Joined(connections, conversationId: 7);
        var hub = new FakeHubContext();

        await BroadcastTo(hub, connections, isCurrent: false, readers: 99).MessageSentAsync(
            Message(conversationId: 9), CancellationToken.None);

        Assert.False(caller.Aborted);
        Assert.Empty(hub.Groups.Removed);
    }

    // The inbox and the badge are not in the thread's group.
    [Fact]
    public async Task EveryAccountInTheThreadIsNudgedWhereverItIs()
    {
        var connections = new ChatConnections();
        var hub = new FakeHubContext();

        await BroadcastTo(hub, connections, isCurrent: true, readers: [7, 12])
            .MessageSentAsync(Message(conversationId: 4), CancellationToken.None);

        Assert.Equal(
            ["conversation-4", "account-7", "account-12"], hub.Clients.SentToGroups);
    }

    private static ChatBroadcast BroadcastTo(
        IHubContext<ChatHub> hub,
        ChatConnections connections,
        bool isCurrent,
        params int[] readers) =>
        new(
            hub,
            connections,
            new StubMembership(readers.Length == 0 ? [Reader] : readers),
            new StubSessions(isCurrent),
            NullLogger<ChatBroadcast>.Instance);

    private static FakeCaller Joined(
        ChatConnections connections,
        int conversationId,
        DateTimeOffset? expiresAt = null)
    {
        var caller = new FakeCaller();

        connections.Opened(
            caller,
            new ChatSession(
                Reader, Version, expiresAt ?? DateTimeOffset.UtcNow.AddHours(1)));
        connections.Joined(caller.ConnectionId, conversationId);

        return caller;
    }

    private static MessageResponse Message(int conversationId) =>
        new()
        {
            Id = 5,
            ConversationId = conversationId,
            SenderUserId = Reader,
            SenderName = "Amila Selimović",
            Body = "Are we still on for Friday?",
            SentAt = DateTime.UtcNow,
        };

    private sealed class StubMembership(IReadOnlyList<int> readers) : IChatMembership
    {
        public Task<bool> ReachesAsync(
            int userId,
            bool isAdministrator,
            int conversationId,
            CancellationToken cancellationToken) => Task.FromResult(true);

        public Task<IReadOnlyList<int>> ParticipantsOfAsync(
            int conversationId,
            CancellationToken cancellationToken) => Task.FromResult(readers);
    }

    private sealed class StubSessions(bool isCurrent) : IUserSessionValidator
    {
        public Task<bool> IsCurrentAsync(
            int userId,
            int tokenVersion,
            CancellationToken cancellationToken) => Task.FromResult(isCurrent);

        public Task<IReadOnlyDictionary<int, int>> CurrentVersionsAsync(
            IReadOnlyCollection<int> userIds,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyDictionary<int, int>>(
                isCurrent
                    ? userIds.ToDictionary(userId => userId, _ => Version)
                    : new Dictionary<int, int>());
    }

    private sealed class FakeHubContext : IHubContext<ChatHub>
    {
        public RecordedClients Clients { get; } = new();

        public RecordedGroups Groups { get; } = new();

        IHubClients IHubContext<ChatHub>.Clients => Clients;

        IGroupManager IHubContext<ChatHub>.Groups => Groups;
    }

    private sealed class RecordedClients : IHubClients
    {
        public List<string> SentToGroups { get; } = [];

        public IClientProxy Group(string groupName)
        {
            SentToGroups.Add(groupName);

            return new SilentProxy();
        }

        public IClientProxy All => new SilentProxy();

        public IClientProxy AllExcept(IReadOnlyList<string> excluded) => new SilentProxy();

        public IClientProxy Client(string connectionId) => new SilentProxy();

        public IClientProxy Clients(IReadOnlyList<string> connectionIds) => new SilentProxy();

        public IClientProxy GroupExcept(
            string groupName,
            IReadOnlyList<string> excludedConnectionIds) => new SilentProxy();

        public IClientProxy Groups(IReadOnlyList<string> groupNames) => new SilentProxy();

        public IClientProxy User(string userId) => new SilentProxy();

        public IClientProxy Users(IReadOnlyList<string> userIds) => new SilentProxy();
    }

    private sealed class SilentProxy : IClientProxy
    {
        public Task SendCoreAsync(
            string method,
            object?[] args,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class RecordedGroups : IGroupManager
    {
        public List<(string Connection, string Group)> Removed { get; } = [];

        public Task AddToGroupAsync(
            string connectionId,
            string groupName,
            CancellationToken cancellationToken = default) => Task.CompletedTask;

        public Task RemoveFromGroupAsync(
            string connectionId,
            string groupName,
            CancellationToken cancellationToken = default)
        {
            Removed.Add((connectionId, groupName));

            return Task.CompletedTask;
        }
    }

    private sealed class FakeCaller : HubCallerContext
    {
        public bool Aborted { get; private set; }

        public override string ConnectionId => "connection-1";

        public override string? UserIdentifier => null;

        public override ClaimsPrincipal? User => new(new ClaimsIdentity(
            [new Claim(GostioClaimTypes.UserId, Reader.ToString(null as IFormatProvider))],
            authenticationType: "Tests"));

        public override IDictionary<object, object?> Items { get; } =
            new Dictionary<object, object?>();

        public override IFeatureCollection Features { get; } = new FeatureCollection();

        public override CancellationToken ConnectionAborted => CancellationToken.None;

        public override void Abort() => Aborted = true;
    }
}
