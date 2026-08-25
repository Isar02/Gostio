using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Chat;

internal sealed record BookingPair(int GuestId, int HostId);

internal sealed class ConversationService(
    GostioDbContext db,
    ICurrentUser currentUser,
    ConversationAccess access) : IConversationService
{
    private static Expression<Func<Conversation, ConversationResponse>> Projection(int callerId) =>
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
            LastMessage = conversation.Messages
                .OrderByDescending(message => message.SentAt)
                .ThenByDescending(message => message.Id)
                .Select(message => new MessageResponse
                {
                    Id = message.Id,
                    ConversationId = message.ConversationId,
                    SenderUserId = message.SenderUserId,
                    SenderName =
                        message.SenderUser.FirstName + " " + message.SenderUser.LastName,
                    Body = message.Body,
                    SentAt = message.SentAt,
                })
                .FirstOrDefault(),
            UnreadCount = conversation.Messages.Count(message =>
                message.SenderUserId != callerId
                && message.SentAt >= (conversation.Participants
                    .Where(participant => participant.UserId == callerId)
                    .Max(participant => participant.LastReadAt) ?? ChatQueries.Never)),
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
            .ToPagedResultAsync(search, Projection(access.CallerId), cancellationToken);

    public Task<ConversationResponse> GetAsync(
        int conversationId,
        CancellationToken cancellationToken) =>
        ReadAsync(conversationId, cancellationToken);

    public Task<ConversationResponse> OpenAsync(
        ConversationOpenRequest request,
        CancellationToken cancellationToken)
    {
        var callerId = currentUser.RequireUserId();

        return (request.ReservationId, request.WithUserId) switch
        {
            (int reservationId, null) =>
                AboutABookingAsync(callerId, reservationId, cancellationToken),
            (null, int hostId) => AnEnquiryAsync(callerId, hostId, cancellationToken),
            (null, null) => throw new ValidationException(
                nameof(request.WithUserId),
                "Name the account to write to, or the booking the thread is about."),
            _ => throw new ValidationException(
                nameof(request.ReservationId),
                "A thread is about a booking or with an account, never both."),
        };
    }

    public async Task<ConversationResponse> OpenSupportAsync(CancellationToken cancellationToken)
    {
        var callerId = currentUser.RequireUserId();

        if (currentUser.IsInRole(RoleNames.Administrator))
        {
            throw new BusinessException(
                "Support is answered from this account rather than asked of it.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await ChatLock.TakeAsync(db, callerId, cancellationToken);

        var opened = await SupportThreadOfAsync(callerId, cancellationToken)
            ?? await WriteAsync(
                ConversationType.Support,
                openedByUserId: callerId,
                reservationId: null,
                [callerId],
                cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(opened, cancellationToken);
    }

    // The two parties of the booking, whichever of them asked. A second thread
    // about one is what the filtered unique index refuses, so the read answers
    // the ordinary case and the insert answers the race underneath it.
    private async Task<ConversationResponse> AboutABookingAsync(
        int callerId,
        int reservationId,
        CancellationToken cancellationToken)
    {
        var parties = await db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Where(ReservationQueries.IsReachableBy(callerId))
            .Select(reservation => new BookingPair(
                reservation.UserId,
                reservation.AccommodationId != null
                    ? reservation.Accommodation!.HostId
                    : reservation.ExperienceSlot!.Experience.HostId))
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw ReservationAccess.Missing(reservationId);

        if (await ThreadAboutAsync(reservationId, cancellationToken) is int standing)
        {
            return await ReadAsync(standing, cancellationToken);
        }

        try
        {
            var opened = await WriteAsync(
                ConversationType.Direct,
                callerId,
                reservationId,
                [parties.GuestId, parties.HostId],
                cancellationToken);

            return await ReadAsync(opened, cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            return await ThreadAboutAsync(reservationId, cancellationToken) is int written
                ? await ReadAsync(written, cancellationToken)
                : throw new BusinessException(
                    "This booking already has a thread. Read it again.");
        }
    }

    // An enquiry is written to an account that hosts, which is the only thread
    // opened between two people with no booking between them. The rule guards
    // opening one rather than finding one, so the thread is looked for first:
    // once it stands, both sides come back to it and only one of them hosts.
    private async Task<ConversationResponse> AnEnquiryAsync(
        int callerId,
        int hostId,
        CancellationToken cancellationToken)
    {
        if (hostId == callerId)
        {
            throw new ValidationException(
                nameof(ConversationOpenRequest.WithUserId),
                "A thread needs somebody else in it.");
        }

        if (await EnquiryBetweenAsync(callerId, hostId, cancellationToken) is int standing)
        {
            return await ReadAsync(standing, cancellationToken);
        }

        var hosts = await db.UserRoles.AnyAsync(
            assignment => assignment.UserId == hostId && assignment.Role.Name == RoleNames.Host,
            cancellationToken);

        if (!hosts)
        {
            throw new ValidationException(
                nameof(ConversationOpenRequest.WithUserId),
                "An enquiry is written to an account that hosts.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await ChatLock.TakeAsync(db, callerId, hostId, cancellationToken);

        var opened = await EnquiryBetweenAsync(callerId, hostId, cancellationToken)
            ?? await WriteAsync(
                ConversationType.Direct,
                callerId,
                reservationId: null,
                [callerId, hostId],
                cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(opened, cancellationToken);
    }

    private async Task<int> WriteAsync(
        ConversationType type,
        int openedByUserId,
        int? reservationId,
        IReadOnlyList<int> participants,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        var conversation = new Conversation
        {
            Type = type,
            OpenedByUserId = openedByUserId,
            ReservationId = reservationId,
            CreatedAt = now,
            Participants =
            [
                .. participants.Select(userId => new ConversationParticipant
                {
                    UserId = userId,
                    JoinedAt = now,
                }),
            ],
        };

        db.Conversations.Add(conversation);

        await db.SaveChangesAsync(cancellationToken);

        return conversation.Id;
    }

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

    private Task<int?> ThreadAboutAsync(int reservationId, CancellationToken cancellationToken) =>
        access.Reachable()
            .Where(conversation => conversation.ReservationId == reservationId)
            .Select(conversation => (int?)conversation.Id)
            .FirstOrDefaultAsync(cancellationToken);

    // Exactly the two of them: an administrator who has stepped into a thread
    // makes it a different thread from the one the pair would open now.
    private Task<int?> EnquiryBetweenAsync(
        int callerId,
        int hostId,
        CancellationToken cancellationToken) =>
        db.Conversations
            .AsNoTracking()
            .Where(conversation =>
                conversation.Type == ConversationType.Direct
                && conversation.ReservationId == null
                && conversation.Participants.Count == 2
                && conversation.Participants.Any(participant => participant.UserId == callerId)
                && conversation.Participants.Any(participant => participant.UserId == hostId))
            .OrderBy(conversation => conversation.Id)
            .Select(conversation => (int?)conversation.Id)
            .FirstOrDefaultAsync(cancellationToken);

    private Task<int?> SupportThreadOfAsync(int callerId, CancellationToken cancellationToken) =>
        db.Conversations
            .AsNoTracking()
            .Where(conversation =>
                conversation.Type == ConversationType.Support
                && conversation.OpenedByUserId == callerId)
            .OrderBy(conversation => conversation.Id)
            .Select(conversation => (int?)conversation.Id)
            .FirstOrDefaultAsync(cancellationToken);

    private async Task<ConversationResponse> ReadAsync(
        int conversationId,
        CancellationToken cancellationToken) =>
        await access.Reachable()
            .Where(conversation => conversation.Id == conversationId)
            .Select(Projection(access.CallerId))
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw ConversationAccess.Missing(conversationId);
}
