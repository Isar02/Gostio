using System.Linq.Expressions;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Chat;

internal static class ChatQueries
{
    // A participant who has read nothing has no timestamp to compare against,
    // and everything said to them is unread rather than nothing.
    public static readonly DateTime Never = DateTime.MinValue;

    // The badge sums this over every thread a caller reaches, and the inbox
    // restates it inside the projection because an expression cannot call
    // another one. The two must answer the same number: a badge that disagrees
    // with the rows beneath it is worse than no badge.
    //
    // The comparison is inclusive because the marking stores the moment it ran
    // rather than the message it saw, and a message written inside the same
    // clock tick would otherwise be counted as read without anybody reading it.
    // Counting one message twice is undone by the next marking; losing one is
    // undone by nothing.
    public static Expression<Func<Conversation, int>> UnreadBy(int callerId) =>
        conversation => conversation.Messages.Count(message =>
            message.SenderUserId != callerId
            && message.SentAt >= (conversation.Participants
                .Where(participant => participant.UserId == callerId)
                .Max(participant => participant.LastReadAt) ?? Never));
}
