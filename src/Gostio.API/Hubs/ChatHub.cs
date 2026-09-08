using System.Security.Claims;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Gostio.API.Hubs;

[Authorize]
public sealed class ChatHub(
    IChatMembership membership,
    IUserSessionValidator sessions,
    ChatConnections connections) : Hub
{
    // A socket outlives the handshake that validated it, so the session is asked
    // about again before anything is done on this connection.
    public override async Task OnConnectedAsync()
    {
        if (SessionOf(Context.User) is not ChatSession session)
        {
            Context.Abort();

            return;
        }

        connections.Opened(Context, session);

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            ChatGroups.ForAccount(session.UserId),
            Context.ConnectionAborted);

        await base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        connections.Closed(Context.ConnectionId);

        return base.OnDisconnectedAsync(exception);
    }

    // Joined on the same question the endpoints answer, and refused the same way.
    public async Task Join(int conversationId)
    {
        await RequireTheSessionIsStillOpenAsync();
        await RequireReachableAsync(conversationId);

        await Groups.AddToGroupAsync(
            Context.ConnectionId, ChatGroups.Of(conversationId), Context.ConnectionAborted);

        connections.Joined(Context.ConnectionId, conversationId);
    }

    // Leaving is never refused: a connection that may not be in a group is a
    // connection that should not stay in one.
    public async Task Leave(int conversationId)
    {
        connections.Left(Context.ConnectionId, conversationId);

        await Groups.RemoveFromGroupAsync(
            Context.ConnectionId, ChatGroups.Of(conversationId), Context.ConnectionAborted);
    }

    private static ChatSession? SessionOf(ClaimsPrincipal? user) =>
        user?.UserId() is int userId
        && user.TokenVersion() is int tokenVersion
        && user.ExpiresAt() is DateTimeOffset expiresAt
            ? new ChatSession(userId, tokenVersion, expiresAt)
            : null;

    private async Task RequireTheSessionIsStillOpenAsync()
    {
        var session = SessionOf(Context.User);

        if (session is not null
            && !session.HasExpired(DateTimeOffset.UtcNow)
            && await sessions.IsCurrentAsync(
                session.UserId, session.TokenVersion, Context.ConnectionAborted))
        {
            return;
        }

        // The socket goes with the refusal, or a signed-out reader keeps a
        // connection that is still in its groups.
        Context.Abort();

        throw new UnauthorizedException("The session this connection was opened under has ended.");
    }

    private async Task RequireReachableAsync(int conversationId)
    {
        var userId = Context.User?.UserId()
            ?? throw new UnauthorizedException("This connection has no signed in user.");

        var reaches = await membership.ReachesAsync(
            userId,
            Context.User?.IsInRole(RoleNames.Administrator) ?? false,
            conversationId,
            Context.ConnectionAborted);

        if (!reaches)
        {
            throw new NotFoundException($"No conversation has the id {conversationId}.");
        }
    }
}
