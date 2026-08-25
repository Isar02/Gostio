using System.Linq.Expressions;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Favorites;

internal static class FavoriteProjection
{
    public static Expression<Func<Favorite, FavoriteResponse>> Of =>
        favorite => new FavoriteResponse
        {
            Id = favorite.Id,
            AccommodationId = favorite.AccommodationId,
            ExperienceId = favorite.ExperienceId,
            ListingTitle = favorite.Accommodation != null
                ? favorite.Accommodation.Title
                : favorite.Experience!.Title,
            CityName = favorite.Accommodation != null
                ? favorite.Accommodation.City.Name
                : favorite.Experience!.City.Name,
            CountryName = favorite.Accommodation != null
                ? favorite.Accommodation.City.Country.Name
                : favorite.Experience!.City.Country.Name,
            Price = favorite.Accommodation != null
                ? favorite.Accommodation.PricePerNight
                : favorite.Experience!.PricePerPerson,
            CoverPhotoId = favorite.Accommodation != null
                ? favorite.Accommodation.Photos
                    .Where(photo => photo.IsCover)
                    .Select(photo => (int?)photo.Id)
                    .FirstOrDefault()
                : favorite.Experience!.Photos
                    .Where(photo => photo.IsCover)
                    .Select(photo => (int?)photo.Id)
                    .FirstOrDefault(),
            IsListingActive = favorite.Accommodation != null
                ? favorite.Accommodation.IsActive
                : favorite.Experience!.IsActive,
            CreatedAt = favorite.CreatedAt,
        };
}
