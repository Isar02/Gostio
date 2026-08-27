using Gostio.Model.Enums;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Recommendations;

internal sealed class AccommodationSignals(GostioDbContext db) : ListingSignals<Accommodation>(db)
{
    protected override IQueryable<Engagement> Kept(int userId) =>
        Db.Favorites
            .AsNoTracking()
            .Where(favorite => favorite.UserId == userId && favorite.AccommodationId != null)
            .Select(favorite => new Engagement(
                favorite.AccommodationId!.Value,
                EngagementKind.Favorite,
                null,
                favorite.CreatedAt));

    protected override IQueryable<Engagement> Booked(int userId) =>
        Db.Reservations
            .AsNoTracking()
            .Where(reservation =>
                reservation.UserId == userId && reservation.AccommodationId != null)
            .Select(reservation => new Engagement(
                reservation.AccommodationId!.Value,
                EngagementKind.Booking,
                Db.Reviews
                    .Where(review => review.ReservationId == reservation.Id)
                    .Select(review => (int?)review.Rating)
                    .FirstOrDefault(),
                reservation.CreatedAt));

    protected override async Task<IReadOnlyList<Candidate>> ReadAsync(
        IQueryable<Accommodation> listings,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var rows = await listings
            .AsNoTracking()
            .Select(accommodation => new
            {
                Listing = new Candidate
                {
                    ListingId = accommodation.Id,
                    Target = SearchTarget.Accommodations,
                    Title = accommodation.Title,
                    CityName = accommodation.City.Name,
                    CountryName = accommodation.City.Country.Name,
                    CategoryName = accommodation.AccommodationCategory.Name,
                    Price = accommodation.PricePerNight,
                    MaxGuests = accommodation.MaxGuests,
                    CoverPhotoId = accommodation.Photos
                        .Where(photo => photo.IsCover)
                        .Select(photo => (int?)photo.Id)
                        .FirstOrDefault(),
                    AverageRating = Db.Reviews
                        .Where(review => review.Reservation.AccommodationId == accommodation.Id)
                        .Average(review => (decimal?)review.Rating),
                    ReviewCount = Db.Reviews
                        .Count(review => review.Reservation.AccommodationId == accommodation.Id),
                    Engagements =
                        Db.Favorites.Count(
                            favorite => favorite.AccommodationId == accommodation.Id)
                        + Db.Reservations.Count(
                            reservation => reservation.AccommodationId == accommodation.Id),
                },
                accommodation.CityId,
                accommodation.AccommodationCategoryId,
                accommodation.AccommodationTypeId,
                TypeName = accommodation.AccommodationType.Name,
            })
            .ToListAsync(cancellationToken);

        var amenities = await Db.AccommodationAmenities
            .AsNoTracking()
            .Where(offering => listings.Any(
                accommodation => accommodation.Id == offering.AccommodationId))
            .Select(offering => new
            {
                offering.AccommodationId,
                offering.AmenityId,
                offering.Amenity.Name,
            })
            .ToListAsync(cancellationToken);

        var offered = amenities.ToLookup(offering => offering.AccommodationId);

        return [.. rows.Select(row => row.Listing with
        {
            Axes =
            [
                new ListingAxis(
                    Feature.Of(RecommendationReasonKind.City, row.CityId),
                    row.Listing.CityName),
                new ListingAxis(
                    Feature.Of(RecommendationReasonKind.Category, row.AccommodationCategoryId),
                    row.Listing.CategoryName),
                new ListingAxis(
                    Feature.Of(
                        RecommendationReasonKind.AccommodationType, row.AccommodationTypeId),
                    row.TypeName),
                .. offered[row.Listing.ListingId].Select(offering => new ListingAxis(
                    Feature.Of(RecommendationReasonKind.Amenity, offering.AmenityId),
                    offering.Name)),
            ],
        })];
    }
}
