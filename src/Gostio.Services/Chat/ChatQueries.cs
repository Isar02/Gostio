using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Chat;

internal static class ChatQueries
{
    // The one statement of who reaches a thread. The endpoints compose it into
    // every read and the hub asks it before it joins a connection to anything,
    // so a caller the hub lets in is exactly a caller the endpoints answer.
    public static Expression<Func<Conversation, bool>> IsReachableBy(
        int callerId,
        bool isAdministrator) =>
        isAdministrator
            ? conversation =>
                conversation.Type == ConversationType.Support
                || conversation.Participants.Any(
                    participant => participant.UserId == callerId)
            : conversation =>
                conversation.Participants.Any(participant => participant.UserId == callerId);

    // A participant who has read nothing has no timestamp to compare against,
    // and everything said to them is unread rather than nothing.
    public static readonly DateTime Never = DateTime.MinValue;

    // The badge sums this and the inbox projection restates it; the two must
    // answer the same number. Only where the caller is in the thread: an
    // administrator reaches every support thread but is in none until they
    // answer, and the marking writes on a participation row that is not there.
    // Inclusive, because the mark stores the moment it ran, not the message.
    public static Expression<Func<Conversation, int>> UnreadBy(int callerId) =>
        conversation => conversation.Participants.Any(
            participant => participant.UserId == callerId)
            ? conversation.Messages.Count(message =>
                message.SenderUserId != callerId
                && message.SentAt >= (conversation.Participants
                    .Where(participant => participant.UserId == callerId)
                    .Max(participant => participant.LastReadAt) ?? Never))
            : 0;
}
