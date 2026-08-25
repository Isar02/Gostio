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

    // The membership rides in the statement that reads the rows, so a thread a
    // caller leaves mid-read cannot hand them a page out of it. The second
    // statement survives only on an empty answer, where it decides whether that
    // is a thread with nothing in it or one that is not theirs.
    public async Task<PagedResult<MessageResponse>> SearchAsync(
        int conversationId,
        PagedRequest paging,
        CancellationToken cancellationToken)
    {
        var visible = access.Reachable()
            .Where(conversation => conversation.Id == conversationId)
            .SelectMany(conversation => conversation.Messages);

        var found = await visible
            .OrderByDescending(message => message.SentAt)
            .ThenByDescending(message => message.Id)
            .ToPagedResultAsync(paging, Projection, cancellationToken);

        if (found.TotalCount == 0)
        {
            await access.RequireReachableAsync(conversationId, cancellationToken);
        }

        return found;
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

        var message = new Message
        {
            ConversationId = conversationId,
            SenderUserId = callerId,
            Body = body,
            SentAt = now,
        };

        if (isParticipant)
        {
            db.Messages.Add(message);
            await db.SaveChangesAsync(cancellationToken);
        }
        else
        {
            await WriteWithMembershipAsync(message, cancellationToken);
        }

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
                && participant.UserId == callerId
                && (participant.LastReadAt == null || participant.LastReadAt < readAt))
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

    // The row that puts an administrator in the thread and the answer that put
    // them there are one write: a message that lands without it is a message in
    // a thread its sender is not in. The account is taken first because the two
    // taps that would each insert that row are the same account twice, and the
    // key it collides on is theirs alone.
    private async Task WriteWithMembershipAsync(
        Message message,
        CancellationToken cancellationToken)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await ChatLock.TakeAsync(db, message.SenderUserId, cancellationToken);

        var joined = await db.ConversationParticipants.AnyAsync(
            participant =>
                participant.ConversationId == message.ConversationId
                && participant.UserId == message.SenderUserId,
            cancellationToken);

        if (!joined)
        {
            db.ConversationParticipants.Add(new ConversationParticipant
            {
                ConversationId = message.ConversationId,
                UserId = message.SenderUserId,
                JoinedAt = message.SentAt,
            });
        }

        db.Messages.Add(message);

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
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
