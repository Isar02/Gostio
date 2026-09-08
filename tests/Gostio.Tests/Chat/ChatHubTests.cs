using System.Security.Claims;
using Gostio.API.Hubs;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.SignalR;

namespace Gostio.Tests.Chat;

// The hub is the one place a caller reaches a thread without an endpoint in
// front of it, so what these ask is whether it still asks the same question.
// The group name is written out rather than read from the hub, because it is
// what a delivery is addressed to and a rename would otherwise go unnoticed.
public sealed class ChatHubTests
{
    private const int Caller = 42;

    private const int Version = 3;

    [Fact]
    public async Task AParticipantIsJoinedToTheThreadTheyAskedFor()
    {
        var membership = new StubMembership(reaches: true);
        var groups = new RecordedGroups();
        var hub = HubFor(membership, groups, RoleNames.Guest);

        await hub.Join(7);

        Assert.Equal(Caller, membership.LastUserId);
        Assert.Equal(7, membership.LastConversationId);
        Assert.False(membership.LastAdministrator);
        Assert.Equal([("connection-1", "conversation-7")], groups.Added);
    }

    [Fact]
    public async Task AConnectionOutsideAThreadIsToldItIsNotThere()
    {
        var groups = new RecordedGroups();
        var hub = HubFor(new StubMembership(reaches: false), groups, RoleNames.Guest);

        await Assert.ThrowsAsync<NotFoundException>(() => hub.Join(7));

        Assert.Empty(groups.Added);
    }

    [Fact]
    public async Task AnAdministratorIsAskedForAsOne()
    {
        var membership = new StubMembership(reaches: true);
        var hub = HubFor(membership, new RecordedGroups(), RoleNames.Administrator);

        await hub.Join(3);

        Assert.True(membership.LastAdministrator);
    }

    [Fact]
    public async Task AConnectionWithNoSignedInUserJoinsNothing()
    {
        var membership = new StubMembership(reaches: true);
        var hub = HubFor(membership, new RecordedGroups(), role: null, signedIn: false);

        await Assert.ThrowsAsync<UnauthorizedException>(() => hub.Join(7));

        Assert.Null(membership.LastConversationId);
    }

    [Fact]
    public async Task LeavingAThreadAsksNobodyForPermission()
    {
        var membership = new StubMembership(reaches: false);
        var groups = new RecordedGroups();
        var hub = HubFor(membership, groups, RoleNames.Guest);

        await hub.Leave(7);

        Assert.Null(membership.LastConversationId);
        Assert.Equal([("connection-1", "conversation-7")], groups.Removed);
    }

    // Validated once at the handshake, so signing out is noticed on the next
    // thing done over the socket.
    [Fact]
    public async Task AConnectionWhoseSessionHasEndedJoinsNothingAndIsClosed()
    {
        var membership = new StubMembership(reaches: true);
        var groups = new RecordedGroups();
        var caller = new FakeCaller(Principal(RoleNames.Guest));

        var hub = HubFor(membership, groups, caller, new StubSessions(isCurrent: false));

        await Assert.ThrowsAsync<UnauthorizedException>(() => hub.Join(7));

        Assert.Null(membership.LastConversationId);
        Assert.Empty(groups.Added);
        Assert.True(caller.Aborted);
    }

    // The token says when it stops being one, and the socket outlives that.
    [Fact]
    public async Task AConnectionWhoseTokenHasExpiredJoinsNothingAndIsClosed()
    {
        var membership = new StubMembership(reaches: true);
        var groups = new RecordedGroups();
        var caller = new FakeCaller(
            Principal(RoleNames.Guest, DateTimeOffset.UtcNow.AddMinutes(-1)));

        var hub = HubFor(membership, groups, caller, new StubSessions(isCurrent: true));

        await Assert.ThrowsAsync<UnauthorizedException>(() => hub.Join(7));

        Assert.Empty(groups.Added);
        Assert.True(caller.Aborted);
    }

    // A join that does not land here is a connection nothing can revoke.
    [Fact]
    public async Task AJoinedConnectionIsFoundOnTheThreadAndAParticipantOnlyOnTheirOwn()
    {
        var connections = new ChatConnections();
        var caller = new FakeCaller(Principal(RoleNames.Guest));

        var hub = HubFor(
            new StubMembership(reaches: true),
            new RecordedGroups(),
            caller,
            new StubSessions(isCurrent: true),
            connections);

        await hub.OnConnectedAsync();
        await hub.Join(7);

        var live = Assert.Single(connections.In(7));

        Assert.Equal(Caller, live.Session.UserId);
        Assert.Equal(Version, live.Session.TokenVersion);
        Assert.Empty(connections.In(8));

        await hub.Leave(7);

        Assert.Empty(connections.In(7));
    }

    [Fact]
    public async Task AConnectionThatDropsIsNoLongerOnAnyThread()
    {
        var connections = new ChatConnections();

        var hub = HubFor(
            new StubMembership(reaches: true),
            new RecordedGroups(),
            new FakeCaller(Principal(RoleNames.Guest)),
            new StubSessions(isCurrent: true),
            connections);

        await hub.OnConnectedAsync();
        await hub.Join(7);
        await hub.OnDisconnectedAsync(null);

        Assert.Empty(connections.In(7));
    }

    private static ChatHub HubFor(
        IChatMembership membership,
        IGroupManager groups,
        string? role,
        bool signedIn = true) =>
        HubFor(
            membership,
            groups,
            new FakeCaller(signedIn ? Principal(role!) : new ClaimsPrincipal()),
            new StubSessions(isCurrent: true));

    private static ChatHub HubFor(
        IChatMembership membership,
        IGroupManager groups,
        FakeCaller caller,
        IUserSessionValidator sessions,
        ChatConnections? connections = null) =>
        new(membership, sessions, connections ?? new ChatConnections())
        {
            Context = caller,
            Groups = groups,
        };

    private static ClaimsPrincipal Principal(string role, DateTimeOffset? expiresAt = null) =>
        new(new ClaimsIdentity(
            [
                new Claim(GostioClaimTypes.UserId, Caller.ToString(null as IFormatProvider)),
                new Claim(
                    GostioClaimTypes.TokenVersion, Version.ToString(null as IFormatProvider)),
                new Claim(
                    "exp",
                    (expiresAt ?? DateTimeOffset.UtcNow.AddHours(1))
                        .ToUnixTimeSeconds()
                        .ToString(null as IFormatProvider)),
                new Claim(GostioClaimTypes.Role, role),
            ],
            authenticationType: "Tests",
            nameType: GostioClaimTypes.Username,
            roleType: GostioClaimTypes.Role));

    private sealed class StubMembership(bool reaches) : IChatMembership
    {
        public Task<IReadOnlyList<int>> ParticipantsOfAsync(
            int conversationId,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<int>>([Caller]);

        public int? LastUserId { get; private set; }

        public int? LastConversationId { get; private set; }

        public bool LastAdministrator { get; private set; }

        public Task<bool> ReachesAsync(
            int userId,
            bool isAdministrator,
            int conversationId,
            CancellationToken cancellationToken)
        {
            LastUserId = userId;
            LastConversationId = conversationId;
            LastAdministrator = isAdministrator;

            return Task.FromResult(reaches);
        }
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

    private sealed class RecordedGroups : IGroupManager
    {
        public List<(string Connection, string Group)> Added { get; } = [];

        public List<(string Connection, string Group)> Removed { get; } = [];

        public Task AddToGroupAsync(
            string connectionId,
            string groupName,
            CancellationToken cancellationToken = default)
        {
            Added.Add((connectionId, groupName));

            return Task.CompletedTask;
        }

        public Task RemoveFromGroupAsync(
            string connectionId,
            string groupName,
            CancellationToken cancellationToken = default)
        {
            Removed.Add((connectionId, groupName));

            return Task.CompletedTask;
        }
    }

    private sealed class FakeCaller(ClaimsPrincipal user) : HubCallerContext
    {
        public override string ConnectionId => "connection-1";

        public override string? UserIdentifier => null;

        public override ClaimsPrincipal? User => user;

        public override IDictionary<object, object?> Items { get; } =
            new Dictionary<object, object?>();

        public override IFeatureCollection Features { get; } = new FeatureCollection();

        public override CancellationToken ConnectionAborted => CancellationToken.None;

        public bool Aborted { get; private set; }

        public override void Abort() => Aborted = true;
    }
}
