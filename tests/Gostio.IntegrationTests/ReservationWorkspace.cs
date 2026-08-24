using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.IntegrationTests;

internal sealed class ReservationWorkspace(DatabaseFixture fixture)
{
    private readonly AccommodationWorkspace listings = new(fixture);

    public async Task<int> APendingStayAsync(string password)
    {
        var (_, listing) = await listings.AListingAsync(password);
        var guest = await fixture.AddUserAsync(password, RoleNames.Guest);
        var checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));
        var now = DateTime.UtcNow;

        await using var db = fixture.CreateContext();

        var reservation = new Reservation
        {
            UserId = guest,
            AccommodationId = listing,
            CheckInDate = checkIn,
            CheckOutDate = checkIn.AddDays(3),
            GuestCount = 2,
            ReservationStatusId = (int)ReservationStatusCode.Pending,
            ExpiresAt = now.AddHours(24),
            AccommodationTotal = 300m,
            CleaningFee = 20m,
            TotalPrice = 320m,
            CreatedAt = now,
        };

        db.Reservations.Add(reservation);
        await db.SaveChangesAsync();

        return reservation.Id;
    }

    public async Task<ReservationStatusCode> StatusOfAsync(int reservationId)
    {
        await using var db = fixture.CreateContext();

        return (ReservationStatusCode)await db.Reservations
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => reservation.ReservationStatusId)
            .SingleAsync();
    }

    public async Task<IReadOnlyList<ReservationStatusHistory>> HistoryOfAsync(int reservationId)
    {
        await using var db = fixture.CreateContext();

        return await db.ReservationStatusHistory
            .AsNoTracking()
            .Where(history => history.ReservationId == reservationId)
            .OrderBy(history => history.ChangedAt)
            .ThenBy(history => history.Id)
            .ToListAsync();
    }
}
