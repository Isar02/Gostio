using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Search;

namespace Gostio.Services.Listings;

internal sealed class AccommodationService(
    GostioDbContext db,
    ICurrentUser currentUser,
    AccommodationAccess access,
    ISearchRecorder searches,
    SearchClock clock)
    : ListingService<
        Accommodation,
        AccommodationResponse,
        AccommodationSearchRequest,
        AccommodationCreateRequest,
        AccommodationUpdateRequest>(db, currentUser, access, searches, clock, "accommodation"),
      IAccommodationService
{
    protected override string StillReferencedMessage =>
        "This accommodation has records that have to be kept. Withdraw it instead of deleting it.";

    protected override Expression<Func<Accommodation, AccommodationResponse>> Projection =>
        accommodation => new AccommodationResponse
        {
            Id = accommodation.Id,
            HostId = accommodation.HostId,
            HostName = accommodation.Host.FirstName + " " + accommodation.Host.LastName,
            Title = accommodation.Title,
            Description = accommodation.Description,
            AccommodationTypeId = accommodation.AccommodationTypeId,
            AccommodationTypeName = accommodation.AccommodationType.Name,
            AccommodationCategoryId = accommodation.AccommodationCategoryId,
            AccommodationCategoryName = accommodation.AccommodationCategory.Name,
            CityId = accommodation.CityId,
            CityName = accommodation.City.Name,
            CountryName = accommodation.City.Country.Name,
            Address = accommodation.Address,
            Latitude = accommodation.Latitude,
            Longitude = accommodation.Longitude,
            MaxGuests = accommodation.MaxGuests,
            Bedrooms = accommodation.Bedrooms,
            Bathrooms = accommodation.Bathrooms,
            PricePerNight = accommodation.PricePerNight,
            CleaningFee = accommodation.CleaningFee,
            IsActive = accommodation.IsActive,
            CoverPhotoId = accommodation.Photos
                .Where(photo => photo.IsCover)
                .Select(photo => (int?)photo.Id)
                .FirstOrDefault(),
            AverageRating = Db.Reviews
                .Where(review => review.Reservation.AccommodationId == accommodation.Id)
                .Average(review => (decimal?)review.Rating),
            ReviewCount = Db.Reviews
                .Count(review => review.Reservation.AccommodationId == accommodation.Id),
            IsFavorite = Db.Favorites.Any(favorite =>
                favorite.UserId == CallerId && favorite.AccommodationId == accommodation.Id),
            CreatedAt = accommodation.CreatedAt,
        };

    protected override IQueryable<Accommodation> Matching(
        IQueryable<Accommodation> query,
        AccommodationSearchRequest search)
    {
        if (search.CityId is int cityId)
        {
            query = query.Where(accommodation => accommodation.CityId == cityId);
        }

        if (search.AccommodationTypeId is int typeId)
        {
            query = query.Where(accommodation => accommodation.AccommodationTypeId == typeId);
        }

        if (search.AccommodationCategoryId is int categoryId)
        {
            query = query.Where(
                accommodation => accommodation.AccommodationCategoryId == categoryId);
        }

        if (search.MinPrice is decimal minPrice)
        {
            query = query.Where(accommodation => accommodation.PricePerNight >= minPrice);
        }

        if (search.MaxPrice is decimal maxPrice)
        {
            query = query.Where(accommodation => accommodation.PricePerNight <= maxPrice);
        }

        if (search.MinGuests is int guests)
        {
            query = query.Where(accommodation => accommodation.MaxGuests >= guests);
        }

        if (search.AmenityIds is { Count: > 0 })
        {
            var wanted = search.AmenityIds.Distinct().ToList();

            query = query.Where(accommodation => accommodation.Amenities
                .Count(offering => wanted.Contains(offering.AmenityId)) == wanted.Count);
        }

        return query;
    }

    protected override SearchSignal Signal(AccommodationSearchRequest search) =>
        new()
        {
            Target = SearchTarget.Accommodations,
            Term = Trimmed(search.Title),
            CityId = search.CityId,
            GuestCount = search.MinGuests,
            MinPrice = search.MinPrice,
            MaxPrice = search.MaxPrice,
        };

    protected override async Task<Accommodation> NewAsync(
        AccommodationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var accommodation = new Accommodation
        {
            HostId = await RequireHostAsync(
                request.HostId, nameof(request.HostId), cancellationToken),
            CreatedAt = DateTime.UtcNow,
        };

        await ApplyUpsertAsync(request, accommodation, cancellationToken);

        return accommodation;
    }

    protected override async Task ApplyAsync(
        AccommodationUpdateRequest request,
        Accommodation accommodation,
        CancellationToken cancellationToken)
    {
        var isActive = request.IsActive ?? throw new ValidationException(
            nameof(request.IsActive), "Say whether the listing is published.");

        await ApplyUpsertAsync(request, accommodation, cancellationToken);

        accommodation.IsActive = isActive;
        accommodation.ModifiedAt = DateTime.UtcNow;
    }

    private async Task ApplyUpsertAsync(
        AccommodationUpsertRequest request,
        Accommodation accommodation,
        CancellationToken cancellationToken)
    {
        await RequireReferenceAsync(
            Db.Cities, request.CityId, nameof(request.CityId), "city", cancellationToken);

        await RequireReferenceAsync(
            Db.AccommodationTypes,
            request.AccommodationTypeId,
            nameof(request.AccommodationTypeId),
            "accommodation type",
            cancellationToken);

        await RequireReferenceAsync(
            Db.AccommodationCategories,
            request.AccommodationCategoryId,
            nameof(request.AccommodationCategoryId),
            "accommodation category",
            cancellationToken);

        accommodation.Title = request.Title.Trim();
        accommodation.Description = request.Description.Trim();
        accommodation.AccommodationTypeId = request.AccommodationTypeId;
        accommodation.AccommodationCategoryId = request.AccommodationCategoryId;
        accommodation.CityId = request.CityId;
        accommodation.Address = request.Address.Trim();
        accommodation.Latitude = request.Latitude;
        accommodation.Longitude = request.Longitude;
        accommodation.MaxGuests = request.MaxGuests;
        accommodation.Bedrooms = request.Bedrooms;
        accommodation.Bathrooms = request.Bathrooms;
        accommodation.PricePerNight = request.PricePerNight;
        accommodation.CleaningFee = request.CleaningFee;
    }
}
