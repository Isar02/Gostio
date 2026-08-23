using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

internal sealed record ListingReferences(int CityId, int TypeId, int CategoryId);

internal static class ListingRequests
{
    private const string Description = "A place to stay, described at the length a listing needs.";

    public static AccommodationCreateRequest New(
        ListingReferences references,
        string title,
        int? hostId = null,
        decimal price = 100m,
        int maxGuests = 4) =>
        new()
        {
            HostId = hostId,
            Title = title,
            Description = Description,
            AccommodationTypeId = references.TypeId,
            AccommodationCategoryId = references.CategoryId,
            CityId = references.CityId,
            Address = "Ferhadija 1",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            MaxGuests = maxGuests,
            Bedrooms = 2,
            Bathrooms = 1,
            PricePerNight = price,
            CleaningFee = 15m,
        };

    public static AccommodationUpdateRequest Edit(
        ListingReferences references,
        string title,
        bool isActive = true,
        decimal price = 100m) =>
        new()
        {
            IsActive = isActive,
            Title = title,
            Description = Description,
            AccommodationTypeId = references.TypeId,
            AccommodationCategoryId = references.CategoryId,
            CityId = references.CityId,
            Address = "Ferhadija 1",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            MaxGuests = 4,
            Bedrooms = 2,
            Bathrooms = 1,
            PricePerNight = price,
            CleaningFee = 15m,
        };
}
