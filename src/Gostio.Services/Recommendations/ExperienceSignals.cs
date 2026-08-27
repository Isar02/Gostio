using Gostio.Model.Enums;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Recommendations;

internal sealed class ExperienceSignals(GostioDbContext db) : ListingSignals<Experience>(db)
{
    protected override IQueryable<Experience> Offered(
        IQueryable<Experience> listings,
        DateTime now) =>
        listings.Where(experience =>
            experience.Slots.Any(slot => slot.IsActive && slot.StartTime > now));

    protected override IQueryable<Engagement> Kept(int userId) =>
        Db.Favorites
            .AsNoTracking()
            .Where(favorite => favorite.UserId == userId && favorite.ExperienceId != null)
            .Select(favorite => new Engagement(
                favorite.ExperienceId!.Value,
                EngagementKind.Favorite,
                null,
                favorite.CreatedAt));

    protected override IQueryable<Engagement> Booked(int userId) =>
        Db.Reservations
            .AsNoTracking()
            .Where(reservation =>
                reservation.UserId == userId && reservation.ExperienceSlotId != null)
            .Select(reservation => new Engagement(
                reservation.ExperienceSlot!.ExperienceId,
                EngagementKind.Booking,
                Db.Reviews
                    .Where(review => review.ReservationId == reservation.Id)
                    .Select(review => (int?)review.Rating)
                    .FirstOrDefault(),
                reservation.CreatedAt));

    protected override async Task<IReadOnlyList<Candidate>> ReadAsync(
        IQueryable<Experience> listings,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var rows = await listings
            .AsNoTracking()
            .Select(experience => new
            {
                Listing = new Candidate
                {
                    ListingId = experience.Id,
                    Target = SearchTarget.Experiences,
                    Title = experience.Title,
                    CityName = experience.City.Name,
                    CountryName = experience.City.Country.Name,
                    CategoryName = experience.ExperienceCategory.Name,
                    Price = experience.PricePerPerson,
                    MaxGuests = experience.Slots
                        .Where(slot => slot.IsActive && slot.StartTime > now)
                        .Max(slot => (int?)slot.Capacity),
                    CoverPhotoId = experience.Photos
                        .Where(photo => photo.IsCover)
                        .Select(photo => (int?)photo.Id)
                        .FirstOrDefault(),
                    AverageRating = Db.Reviews
                        .Where(review =>
                            review.Reservation.ExperienceSlot!.ExperienceId == experience.Id)
                        .Average(review => (decimal?)review.Rating),
                    ReviewCount = Db.Reviews
                        .Count(review =>
                            review.Reservation.ExperienceSlot!.ExperienceId == experience.Id),
                    Engagements =
                        Db.Favorites.Count(favorite => favorite.ExperienceId == experience.Id)
                        + Db.Reservations.Count(reservation =>
                            reservation.ExperienceSlot!.ExperienceId == experience.Id),
                },
                experience.CityId,
                experience.ExperienceCategoryId,
            })
            .ToListAsync(cancellationToken);

        return [.. rows.Select(row => row.Listing with
        {
            Axes =
            [
                new ListingAxis(
                    Feature.Of(RecommendationReasonKind.City, row.CityId),
                    row.Listing.CityName),
                new ListingAxis(
                    Feature.Of(RecommendationReasonKind.Category, row.ExperienceCategoryId),
                    row.Listing.CategoryName),
            ],
        })];
    }
}
