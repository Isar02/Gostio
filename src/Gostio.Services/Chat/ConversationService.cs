using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Chat;

internal sealed class ConversationService(ConversationAccess access) : IConversationService
{
    private static Expression<Func<Conversation, ConversationResponse>> Projection =>
        conversation => new ConversationResponse
        {
            Id = conversation.Id,
            Type = conversation.Type.ToString(),
            ReservationId = conversation.ReservationId,
            ListingTitle = conversation.Reservation == null
                ? null
                : conversation.Reservation.Accommodation != null
                    ? conversation.Reservation.Accommodation.Title
                    : conversation.Reservation.ExperienceSlot!.Experience.Title,
            Participants = conversation.Participants
                .OrderBy(participant => participant.JoinedAt)
                .ThenBy(participant => participant.UserId)
                .Select(participant => new ConversationParticipantResponse
                {
                    UserId = participant.UserId,
                    Username = participant.User.Username,
                    Name = participant.User.FirstName + " " + participant.User.LastName,
                    JoinedAt = participant.JoinedAt,
                    LastReadAt = participant.LastReadAt,
                })
                .ToList(),
            CreatedAt = conversation.CreatedAt,
            LastActivityAt =
                conversation.Messages.Max(message => (DateTime?)message.SentAt)
                ?? conversation.CreatedAt,
        };

    public Task<PagedResult<ConversationResponse>> SearchAsync(
        ConversationSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(access.Reachable(), search)
            .OrderByDescending(conversation =>
                conversation.Messages.Max(message => (DateTime?)message.SentAt)
                ?? conversation.CreatedAt)
            .ThenByDescending(conversation => conversation.Id)
            .ToPagedResultAsync(search, Projection, cancellationToken);

    public Task<ConversationResponse> GetAsync(
        int conversationId,
        CancellationToken cancellationToken) =>
        ReadAsync(conversationId, cancellationToken);

    private static IQueryable<Conversation> Matching(
        IQueryable<Conversation> query,
        ConversationSearchRequest search)
    {
        if (search.Type is ConversationType type)
        {
            query = query.Where(conversation => conversation.Type == type);
        }

        if (search.ReservationId is int reservationId)
        {
            query = query.Where(conversation => conversation.ReservationId == reservationId);
        }

        if (search.WithUserId is int userId)
        {
            query = query.Where(conversation =>
                conversation.Participants.Any(participant => participant.UserId == userId));
        }

        return query;
    }

    private async Task<ConversationResponse> ReadAsync(
        int conversationId,
        CancellationToken cancellationToken) =>
        await access.Reachable()
            .Where(conversation => conversation.Id == conversationId)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw ConversationAccess.Missing(conversationId);
}
