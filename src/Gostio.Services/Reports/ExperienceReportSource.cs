using Gostio.Model.Enums;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reports;

internal sealed class ExperienceReportSource(GostioDbContext db) : IListingReportSource
{
    public async Task<IReadOnlyList<ListingTally>> PublishedAsync(
        ReportScope scope,
        CancellationToken cancellationToken) =>
        await scope
            .Narrow(db.Experiences.AsNoTracking(), host => listing => listing.HostId == host)
            .GroupBy(listing => new
            {
                listing.CityId,
                City = listing.City.Name,
                CategoryId = listing.ExperienceCategoryId,
                Category = listing.ExperienceCategory.Name,
            })
            .Select(pair => new ListingTally(
                pair.Key.CityId,
                pair.Key.City,
                pair.Key.CategoryId,
                pair.Key.Category,
                pair.Count(listing => listing.IsActive)))
            .ToListAsync(cancellationToken);

    // Seats rather than nights: on this side a term is what holds the places,
    // and what a booking took out of it is the party it seated.
    public async Task<IReadOnlyList<BookingTally>> BookingsAsync(
        ReportRange range,
        ReportScope scope,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        return await scope
            .Narrow(
                db.Reservations.AsNoTracking(),
                host => booking => booking.ExperienceSlot!.Experience.HostId == host)
            .Where(booking => booking.ExperienceSlotId != null)
            .Where(booking => booking.CreatedAt >= from && booking.CreatedAt < until)
            .Where(ReportQueries.IsSold)
            .GroupBy(booking => new
            {
                booking.ExperienceSlot!.Experience.CityId,
                CategoryId = booking.ExperienceSlot!.Experience.ExperienceCategoryId,
            })
            .Select(pair => new BookingTally(
                pair.Key.CityId,
                pair.Key.CategoryId,
                pair.Count(),
                pair.Sum(booking => booking.GuestCount)))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ChargeTally>> ChargesAsync(
        ReportRange range,
        ReportScope scope,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        return await scope
            .Narrow(
                db.Payments.AsNoTracking(),
                host => payment =>
                    payment.Reservation.ExperienceSlot!.Experience.HostId == host)
            .Where(payment => payment.Status == PaymentStatus.Succeeded)
            .Where(payment => payment.Reservation.ExperienceSlotId != null)
            .Where(payment =>
                payment.Reservation.CreatedAt >= from && payment.Reservation.CreatedAt < until)
            .GroupBy(payment => new
            {
                payment.Currency,
                payment.Reservation.ExperienceSlot!.Experience.CityId,
                CategoryId = payment.Reservation.ExperienceSlot!.Experience.ExperienceCategoryId,
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
        ReportScope scope,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        return await scope
            .Narrow(
                db.Reviews.AsNoTracking(),
                host => review =>
                    review.Reservation.ExperienceSlot!.Experience.HostId == host)
            .Where(review => review.Reservation.ExperienceSlotId != null)
            .Where(review =>
                review.Reservation.CreatedAt >= from && review.Reservation.CreatedAt < until)
            .GroupBy(review => new
            {
                review.Reservation.ExperienceSlot!.Experience.CityId,
                CategoryId = review.Reservation.ExperienceSlot!.Experience.ExperienceCategoryId,
            })
            .Select(pair => new ReviewTally(
                pair.Key.CityId,
                pair.Key.CategoryId,
                pair.Count(),
                pair.Sum(review => review.Rating)))
            .ToListAsync(cancellationToken);
    }
}
