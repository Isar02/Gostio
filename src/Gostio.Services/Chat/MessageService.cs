using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Chat;

internal sealed class MessageService(
    GostioDbContext db,
    ConversationAccess access,
    IChatBroadcast broadcast) : IMessageService
{
    private static Expression<Func<Message, MessageResponse>> Projection =>
        message => new MessageResponse
        {
            Id = message.Id,
            ConversationId = message.ConversationId,
            SenderUserId = message.SenderUserId,
            SenderName = message.SenderUser.FirstName + " " + message.SenderUser.LastName,
            Body = message.Body,
            SentAt = message.SentAt,
        };

    public async Task<PagedResult<MessageResponse>> SearchAsync(
        int conversationId,
        PagedRequest paging,
        CancellationToken cancellationToken)
    {
        await access.RequireReachableAsync(conversationId, cancellationToken);

        return await db.Messages
            .AsNoTracking()
            .Where(message => message.ConversationId == conversationId)
            .OrderByDescending(message => message.SentAt)
            .ThenByDescending(message => message.Id)
            .ToPagedResultAsync(paging, Projection, cancellationToken);
    }

    public async Task<MessageResponse> SendAsync(
        int conversationId,
        MessageSendRequest request,
        CancellationToken cancellationToken)
    {
        var callerId = access.CallerId;
        var body = Trimmed(request.Body)
            ?? throw new ValidationException(
                nameof(request.Body), "A message needs something in it.");

        // Nullable, so a thread nobody may reach is told apart from one the
        // caller reaches without being in it yet.
        var isParticipant = await access.Reachable()
            .Where(conversation => conversation.Id == conversationId)
            .Select(conversation => (bool?)conversation.Participants.Any(
                participant => participant.UserId == callerId))
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw ConversationAccess.Missing(conversationId);

        var now = DateTime.UtcNow;

        if (!isParticipant)
        {
            await JoinAsync(conversationId, callerId, now, cancellationToken);
        }

        var message = new Message
        {
            ConversationId = conversationId,
            SenderUserId = callerId,
            Body = body,
            SentAt = now,
        };

        db.Messages.Add(message);

        await db.SaveChangesAsync(cancellationToken);

        var written = await ReadAsync(message.Id, cancellationToken);

        await broadcast.MessageSentAsync(written, cancellationToken);

        return written;
    }

    public async Task<UnreadCountResponse> MarkReadAsync(
        int conversationId,
        CancellationToken cancellationToken)
    {
        var callerId = access.CallerId;

        await access.RequireReachableAsync(conversationId, cancellationToken);

        DateTime? readAt = DateTime.UtcNow;

        await db.ConversationParticipants
            .Where(participant =>
                participant.ConversationId == conversationId
                && participant.UserId == callerId)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(participant => participant.LastReadAt, readAt),
                cancellationToken);

        return await UnreadAsync(cancellationToken);
    }

    public async Task<UnreadCountResponse> UnreadAsync(CancellationToken cancellationToken) =>
        new()
        {
            Unread = await access.Reachable()
                .SumAsync(ChatQueries.UnreadBy(access.CallerId), cancellationToken),
        };

    // Two administrators answering the same thread at once both find themselves
    // outside it and both write the row. The second is the key saying so, and
    // it changes nothing the first has not already done — but the row it failed
    // on is still added as far as the tracker knows, and the message written
    // next would carry it back into the same failure.
    private async Task JoinAsync(
        int conversationId,
        int callerId,
        DateTime joinedAt,
        CancellationToken cancellationToken)
    {
        var joined = db.ConversationParticipants.Add(new ConversationParticipant
        {
            ConversationId = conversationId,
            UserId = callerId,
            JoinedAt = joinedAt,
        });

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            joined.State = EntityState.Detached;
        }
    }

    private async Task<MessageResponse> ReadAsync(
        int messageId,
        CancellationToken cancellationToken) =>
        await db.Messages
            .AsNoTracking()
            .Where(message => message.Id == messageId)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw new NotFoundException($"No message has the id {messageId}.");

    private static string? Trimmed(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
