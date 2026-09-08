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

    public async Task<IReadOnlyList<int>> ParticipantsOfAsync(
        int conversationId,
        CancellationToken cancellationToken) =>
        await db.ConversationParticipants
            .AsNoTracking()
            .Where(participant => participant.ConversationId == conversationId)
            .Select(participant => participant.UserId)
            .ToListAsync(cancellationToken);
}
