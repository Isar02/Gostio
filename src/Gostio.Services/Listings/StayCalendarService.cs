using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

// What the guest sees before they pick: the nights that can still be booked and
// what each of them costs. A day is drawn from the exceptions the host wrote and
// the bookings somebody else made, and the price comes from the method the
// booking prices itself with, so the grid and the total cannot disagree.
internal sealed class StayCalendarService(
    GostioDbContext db,
    AccommodationAccess access,
    TimeProvider clock) : IStayCalendarService
{
    public async Task<IReadOnlyList<StayCalendarDayResponse>> ReadAsync(
        int accommodationId,
        StayCalendarRequest request,
        CancellationToken cancellationToken)
    {
        var window = StayCalendarWindow.Require(request);

        var basePrice = await access.VisibleListings()
            .Where(listing => listing.Id == accommodationId)
            .Select(listing => (decimal?)listing.PricePerNight)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw access.Missing(accommodationId);

        var ranges = await db.AccommodationAvailability
            .AsNoTracking()
            .Where(range => range.AccommodationId == accommodationId
                && range.StartDate <= window.To
                && window.From <= range.EndDate)
            .Select(range => new
            {
                range.StartDate,
                range.EndDate,
                range.IsAvailable,
                range.PriceOverride,
            })
            .ToListAsync(cancellationToken);

        // The half-open stay against the inclusive window: a booking that checks
        // out on the first day asked for takes no night inside it.
        var taken = await db.Reservations
            .AsNoTracking()
            .Where(ReservationQueries.IsActive(clock.GetUtcNow().UtcDateTime))
            .Where(booking => booking.AccommodationId == accommodationId
                && booking.CheckInDate <= window.To
                && window.From < booking.CheckOutDate)
            .Select(booking => new { booking.CheckInDate, booking.CheckOutDate })
            .ToListAsync(cancellationToken);

        var blocked = ranges.Where(range => !range.IsAvailable).ToList();

        var overrides = ranges
            .Where(range => range.PriceOverride is not null)
            .Select(range => new PricedRange(
                range.StartDate, range.EndDate, range.PriceOverride!.Value))
            .ToList();

        return
        [
            .. window.Days().Select(night => new StayCalendarDayResponse
            {
                Date = night,
                IsBookable =
                    !blocked.Any(range =>
                        range.StartDate <= night && night <= range.EndDate)
                    && !taken.Any(booking =>
                        booking.CheckInDate <= night && night < booking.CheckOutDate),
                Price = ReservationPricing.PriceOf(night, basePrice, overrides),
            }),
        ];
    }
}
