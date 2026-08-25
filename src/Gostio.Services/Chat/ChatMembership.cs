using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Chat;

internal sealed class ChatMembership(GostioDbContext db) : IChatMembership
{
    public Task<bool> ReachesAsync(
        int userId,
        bool isAdministrator,
        int conversationId,
        CancellationToken cancellationToken) =>
        db.Conversations
            .AsNoTracking()
            .Where(ChatQueries.IsReachableBy(userId, isAdministrator))
            .AnyAsync(conversation => conversation.Id == conversationId, cancellationToken);
}
