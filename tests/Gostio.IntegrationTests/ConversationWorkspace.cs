using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Chat;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed record BookedPair(int Guest, int Host, int Reservation);

internal sealed class ConversationWorkspace(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-somebody-writing";

    private readonly ReservationWorkspace bookings = new(fixture);

    public Task<int> AGuestAsync() => fixture.AddUserAsync(Password, RoleNames.Guest);

    public Task<int> AHostAsync() => fixture.AddUserAsync(Password, RoleNames.Host);

    public Task<int> AnAdministratorAsync() =>
        fixture.AddUserAsync(Password, RoleNames.Administrator);

    // A stay somebody holds, which is what a thread about a booking hangs off.
    public async Task<BookedPair> ABookingAsync()
    {
        var (host, listing) = await bookings.AListingAsync();
        var guest = await AGuestAsync();
        var checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(45));
        var now = DateTime.UtcNow;

        await using var db = fixture.CreateContext();

        var reservation = new Reservation
        {
            UserId = guest,
            AccommodationId = listing,
            CheckInDate = checkIn,
            CheckOutDate = checkIn.AddDays(2),
            GuestCount = 2,
            ReservationStatusId = (int)ReservationStatusCode.Confirmed,
            ExpiresAt = now.AddHours(24),
            AccommodationTotal = 200m,
            CleaningFee = 15m,
            TotalPrice = 215m,
            CreatedAt = now,
        };

        db.Reservations.Add(reservation);
        await db.SaveChangesAsync();

        return new BookedPair(guest, host, reservation.Id);
    }

    public Task<int> ADirectThreadAsync(params int[] participants) =>
        AThreadAsync(ConversationType.Direct, reservationId: null, participants);

    public Task<int> AThreadAboutAsync(int reservationId, params int[] participants) =>
        AThreadAsync(ConversationType.Direct, reservationId, participants);

    public Task<int> ASupportThreadAsync(params int[] participants) =>
        AThreadAsync(ConversationType.Support, reservationId: null, participants);

    public async Task SayAsync(int conversationId, int senderId, string body, DateTime sentAt)
    {
        await using var db = fixture.CreateContext();

        db.Messages.Add(new Message
        {
            ConversationId = conversationId,
            SenderUserId = senderId,
            Body = body,
            SentAt = sentAt,
        });

        await db.SaveChangesAsync();
    }

    public Task<ConversationResponse> ReadAsync(int actor, string role, int conversationId) =>
        AsAsync(actor, role, service => service.GetAsync(conversationId, default));

    public Task<PagedResult<ConversationResponse>> SearchAsync(
        int actor,
        string role,
        ConversationSearchRequest? search = null) =>
        AsAsync(
            actor,
            role,
            service => service.SearchAsync(search ?? new ConversationSearchRequest(), default));

    private async Task<int> AThreadAsync(
        ConversationType type,
        int? reservationId,
        IReadOnlyList<int> participants)
    {
        var now = DateTime.UtcNow;

        await using var db = fixture.CreateContext();

        var conversation = new Conversation
        {
            Type = type,
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
        await db.SaveChangesAsync();

        return conversation.Id;
    }

    private async Task<TResult> AsAsync<TResult>(
        int actor,
        string role,
        Func<IConversationService, Task<TResult>> work)
    {
        await using var services = fixture.BuildServices(ListingWorkspace.Caller(actor, role));

        return await work(services.GetRequiredService<IConversationService>());
    }
}
