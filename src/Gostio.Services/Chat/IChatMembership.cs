namespace Gostio.Services.Chat;

// What a connection is asked before it is joined to a thread. The caller comes
// from the token the hub validated rather than from an HTTP context, because a
// socket outlives the request that opened it.
public interface IChatMembership
{
    Task<bool> ReachesAsync(
        int userId,
        bool isAdministrator,
        int conversationId,
        CancellationToken cancellationToken);
}
