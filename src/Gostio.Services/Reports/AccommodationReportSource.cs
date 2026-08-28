using Gostio.Model.Enums;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reports;

internal sealed class AccommodationReportSource(GostioDbContext db) : IListingReportSource
{
    public async Task<IReadOnlyList<ListingTally>> PublishedAsync(
        CancellationToken cancellationToken) =>
        await db.Accommodations
            .AsNoTracking()
            .GroupBy(listing => new
            {
                listing.CityId,
                City = listing.City.Name,
                CategoryId = listing.AccommodationCategoryId,
                Category = listing.AccommodationCategory.Name,
            })
            .Select(pair => new ListingTally(
                pair.Key.CityId,
                pair.Key.City,
                pair.Key.CategoryId,
                pair.Key.Category,
                pair.Count(listing => listing.IsActive)))
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<BookingTally>> BookingsAsync(
        ReportRange range,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        return await db.Reservations
            .AsNoTracking()
            .Where(booking => booking.AccommodationId != null)
            .Where(booking => booking.CreatedAt >= from && booking.CreatedAt < until)
            .Where(ReportQueries.IsSold)
            .GroupBy(booking => new
            {
                booking.Accommodation!.CityId,
                CategoryId = booking.Accommodation!.AccommodationCategoryId,
            })
            .Select(pair => new BookingTally(
                pair.Key.CityId,
                pair.Key.CategoryId,
                pair.Count(),
                pair.Sum(booking =>
                    booking.CheckOutDate!.Value.DayNumber - booking.CheckInDate!.Value.DayNumber)))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ChargeTally>> ChargesAsync(
        ReportRange range,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        return await db.Payments
            .AsNoTracking()
            .Where(payment => payment.Status == PaymentStatus.Succeeded)
            .Where(payment => payment.Reservation.AccommodationId != null)
            .Where(payment =>
                payment.Reservation.CreatedAt >= from && payment.Reservation.CreatedAt < until)
            .GroupBy(payment => new
            {
                payment.Currency,
                payment.Reservation.Accommodation!.CityId,
                CategoryId = payment.Reservation.Accommodation!.AccommodationCategoryId,
            })
            .Select(pair => new ChargeTally(
                pair.Key.CityId,
                pair.Key.CategoryId,
                pair.Key.Currency,
                pair.Sum(payment => payment.Amount)))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ReviewTally>> ReviewsAsync(
        ReportRange range,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        return await db.Reviews
            .AsNoTracking()
            .Where(review => review.Reservation.AccommodationId != null)
            .Where(review =>
                review.Reservation.CreatedAt >= from && review.Reservation.CreatedAt < until)
            .GroupBy(review => new
            {
                review.Reservation.Accommodation!.CityId,
                CategoryId = review.Reservation.Accommodation!.AccommodationCategoryId,
            })
            .Select(pair => new ReviewTally(
                pair.Key.CityId,
                pair.Key.CategoryId,
                pair.Count(),
                pair.Sum(review => review.Rating)))
            .ToListAsync(cancellationToken);
    }
}
