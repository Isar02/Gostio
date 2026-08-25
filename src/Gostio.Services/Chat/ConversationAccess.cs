using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Chat;

internal sealed class ConversationAccess(GostioDbContext db, ICurrentUser currentUser)
{
    // Membership is the whole rule, and it composes into the statement that
    // reads the rows, so nothing a search names widens what a caller sees and a
    // thread that is not theirs answers 404 rather than 403. A support thread is
    // the one exception: it is addressed to whoever is on duty rather than to a
    // named person, so every administrator reaches it and answering one is what
    // puts them in it.
    public IQueryable<Conversation> Reachable()
    {
        var callerId = currentUser.RequireUserId();
        var query = db.Conversations.AsNoTracking();

        return currentUser.IsInRole(RoleNames.Administrator)
            ? query.Where(conversation =>
                conversation.Type == ConversationType.Support
                || conversation.Participants.Any(
                    participant => participant.UserId == callerId))
            : query.Where(conversation =>
                conversation.Participants.Any(participant => participant.UserId == callerId));
    }

    public async Task RequireReachableAsync(int conversationId, CancellationToken cancellationToken)
    {
        var reachable = await Reachable()
            .AnyAsync(conversation => conversation.Id == conversationId, cancellationToken);

        if (!reachable)
        {
            throw Missing(conversationId);
        }
    }

    public static NotFoundException Missing(int conversationId) =>
        new($"No conversation has the id {conversationId}.");
}
