using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

internal sealed record CalendarRange(
    DateOnly StartDate,
    DateOnly EndDate,
    bool IsAvailable,
    decimal? PriceOverride);

// The place a reservation takes: the lock that queues the callers after it and
// the questions that say whether it is still free. A term takes the experience
// lock rather than one of its own, because lowering a slot's capacity takes
// that one and the two have to queue. Creation asks before it writes a
// reservation and confirmation asks again, because a hold that lapsed stopped
// holding anything.
internal sealed class ReservationPlaces(
    GostioDbContext db,
    AccommodationAccess accommodations,
    ExperienceAccess experiences)
{
    public Task LockAccommodationAsync(int accommodationId, CancellationToken cancellationToken) =>
        accommodations.LockAsync(accommodationId, cancellationToken);

    public Task LockExperienceAsync(int experienceId, CancellationToken cancellationToken) =>
        experiences.LockAsync(experienceId, cancellationToken);

    // Inclusive on the range and half-open on the stay: a range covering the
    // check-out day alone covers no night that is being booked.
    public async Task<IReadOnlyList<CalendarRange>> RangesOverAsync(
        int accommodationId,
        DateOnly checkIn,
        DateOnly checkOut,
        CancellationToken cancellationToken) =>
        await db.AccommodationAvailability
            .AsNoTracking()
            .Where(range => range.AccommodationId == accommodationId
                && range.StartDate < checkOut
                && range.EndDate >= checkIn)
            .Select(range => new CalendarRange(
                range.StartDate, range.EndDate, range.IsAvailable, range.PriceOverride))
            .ToListAsync(cancellationToken);

    public Task<bool> AreTheNightsTakenAsync(
        int accommodationId,
        DateOnly checkIn,
        DateOnly checkOut,
        DateTime now,
        int? exceptReservationId,
        CancellationToken cancellationToken) =>
        Active(now, exceptReservationId)
            .Where(other => other.AccommodationId == accommodationId
                && other.CheckInDate < checkOut
                && checkIn < other.CheckOutDate)
            .AnyAsync(cancellationToken);

    public Task<int> SeatsTakenAsync(
        int slotId,
        DateTime now,
        int? exceptReservationId,
        CancellationToken cancellationToken) =>
        Active(now, exceptReservationId)
            .Where(other => other.ExperienceSlotId == slotId)
            .SumAsync(other => other.GuestCount, cancellationToken);

    public Task<bool> HoldsAPlaceAsync(
        int slotId,
        int guestId,
        DateTime now,
        int? exceptReservationId,
        CancellationToken cancellationToken) =>
        Active(now, exceptReservationId)
            .Where(other => other.ExperienceSlotId == slotId && other.UserId == guestId)
            .AnyAsync(cancellationToken);

    // A confirmation leaves its own row out: it is pending and still active
    // until the hold lapses, so a count that kept it would find it in the way.
    private IQueryable<Reservation> Active(DateTime now, int? exceptReservationId)
    {
        var active = db.Reservations.AsNoTracking().Where(ReservationQueries.IsActive(now));

        return exceptReservationId is int self
            ? active.Where(other => other.Id != self)
            : active;
    }
}
