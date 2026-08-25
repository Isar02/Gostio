namespace Gostio.Model.Responses;

public sealed class FavoriteResponse : IIdentified
{
    public required int Id { get; init; }

    public int? AccommodationId { get; init; }

    public int? ExperienceId { get; init; }

    public required string ListingTitle { get; init; }

    public required string CityName { get; init; }

    public required string CountryName { get; init; }

    public required decimal Price { get; init; }

    public required int? CoverPhotoId { get; init; }

    public required bool IsListingActive { get; init; }

    public required DateTime CreatedAt { get; init; }
}
