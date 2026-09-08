using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.SignalR;

namespace Gostio.API.Hubs;

// A delivery never fails what raised it: a message is written whether or not
// anybody is listening, and a hub that cannot reach a connection is not the
// sender's problem.
public sealed class ChatBroadcast(
    IHubContext<ChatHub> hub,
    ChatConnections connections,
    IChatMembership membership,
    IUserSessionValidator sessions,
    ILogger<ChatBroadcast> logger) : IChatBroadcast
{
    public const string MessageSent = "MessageSent";

    // What tells an inbox or a badge outside the thread that something moved.
    public const string ThreadTouched = "ThreadTouched";

    public async Task MessageSentAsync(MessageResponse message, CancellationToken cancellationToken)
    {
        try
        {
            var readers = await membership.ParticipantsOfAsync(
                message.ConversationId, cancellationToken);

            await CloseTheSessionsThatEndedAsync(
                message.ConversationId, readers, cancellationToken);

            await hub.Clients
                .Group(ChatGroups.Of(message.ConversationId))
                .SendAsync(MessageSent, message, cancellationToken);

            foreach (var reader in readers)
            {
                await hub.Clients
                    .Group(ChatGroups.ForAccount(reader))
                    .SendAsync(ThreadTouched, message.ConversationId, cancellationToken);
            }
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(
                failure,
                "Message {MessageId} was written but never left the hub.",
                message.Id);
        }
    }

    // A delivery is what happens on an idle socket, so it is where a session
    // that ended elsewhere is noticed. The version is asked rather than the
    // event that moved it, so every way of ending one is caught.
    private async Task CloseTheSessionsThatEndedAsync(
        int conversationId,
        IReadOnlyCollection<int> readers,
        CancellationToken cancellationToken)
    {
        var live = connections.Reaching(conversationId, readers);

        if (live.Count == 0)
        {
            return;
        }

        var now = DateTimeOffset.UtcNow;

        var open = await sessions.CurrentVersionsAsync(
            [.. live.Select(connection => connection.Session.UserId).Distinct()],
            cancellationToken);

        foreach (var connection in live)
        {
            if (!connection.Session.HasExpired(now)
                && open.TryGetValue(connection.Session.UserId, out var version)
                && version == connection.Session.TokenVersion)
            {
                continue;
            }

            // Out of the groups first: an abort leaves them only when the
            // disconnect lands, by which time the messages have gone.
            await hub.Groups.RemoveFromGroupAsync(
                connection.ConnectionId, ChatGroups.Of(conversationId), cancellationToken);

            await hub.Groups.RemoveFromGroupAsync(
                connection.ConnectionId,
                ChatGroups.ForAccount(connection.Session.UserId),
                cancellationToken);

            connections.Left(connection.ConnectionId, conversationId);
            connection.Close();

            logger.LogInformation(
                "A connection on conversation {ConversationId} was closed because the session it "
                    + "was opened under had ended.",
                conversationId);
        }
    }
}
