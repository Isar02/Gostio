using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Gostio.API.Hubs;

[Authorize]
public sealed class ChatHub(IChatMembership membership) : Hub
{
    // Nothing is delivered to a connection that has not asked for a thread, and
    // nothing is joined without the same question the endpoints answer: is this
    // caller in it. A connection that asks for somebody else's thread is told it
    // is not there, the way the endpoints tell it.
    public async Task Join(int conversationId)
    {
        await RequireReachableAsync(conversationId);

        await Groups.AddToGroupAsync(
            Context.ConnectionId, ChatGroups.Of(conversationId), Context.ConnectionAborted);
    }

    // Leaving is never refused: a connection that may not be in a group is a
    // connection that should not stay in one.
    public Task Leave(int conversationId) =>
        Groups.RemoveFromGroupAsync(
            Context.ConnectionId, ChatGroups.Of(conversationId), Context.ConnectionAborted);

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
