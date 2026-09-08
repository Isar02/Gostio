using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;

namespace Gostio.API.Hubs;

// Which session is behind an open socket, and which threads it joined. SignalR
// keeps its groups but will not say who is in one, and a session that ends has
// to reach connections already inside.
public sealed class ChatConnections
{
    private readonly ConcurrentDictionary<string, LiveConnection> live =
        new(StringComparer.Ordinal);

    public void Opened(HubCallerContext context, ChatSession session) =>
        live[context.ConnectionId] = new LiveConnection(context, session);

    public void Closed(string connectionId) => live.TryRemove(connectionId, out _);

    public void Joined(string connectionId, int conversationId)
    {
        if (live.TryGetValue(connectionId, out var connection))
        {
            connection.Threads[conversationId] = true;
        }
    }

    public void Left(string connectionId, int conversationId)
    {
        if (live.TryGetValue(connectionId, out var connection))
        {
            connection.Threads.TryRemove(conversationId, out _);
        }
    }

    // A snapshot: the caller closes some of what it is handed.
    public IReadOnlyList<LiveConnection> In(int conversationId) =>
        [.. live.Values.Where(connection => connection.Threads.ContainsKey(conversationId))];

    // Everything a delivery would reach: the sockets reading the thread and
    // every socket the accounts in it hold.
    public IReadOnlyList<LiveConnection> Reaching(
        int conversationId,
        IReadOnlyCollection<int> readers) =>
        [.. live.Values.Where(connection =>
            connection.Threads.ContainsKey(conversationId)
            || readers.Contains(connection.Session.UserId))];
}

// Read from the token at the handshake, the only moment SignalR validates one.
public sealed record ChatSession(int UserId, int TokenVersion, DateTimeOffset ExpiresAt)
{
    public bool HasExpired(DateTimeOffset now) => ExpiresAt <= now;
}

public sealed class LiveConnection(HubCallerContext context, ChatSession session)
{
    public ChatSession Session { get; } = session;

    public string ConnectionId => context.ConnectionId;

    public ConcurrentDictionary<int, bool> Threads { get; } = new();

    public void Close() => context.Abort();
}
