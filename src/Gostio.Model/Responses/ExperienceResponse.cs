namespace Gostio.Model.Responses;

// The photos are absent on purpose: they are columns of bytes, and they are
// served by an endpoint of their own rather than dragged through every list.
public sealed class ExperienceResponse : IIdentified
{
    public required int Id { get; init; }

    public required int HostId { get; init; }

    public required string HostName { get; init; }

    public required string Title { get; init; }

    public required string Description { get; init; }

    public required int ExperienceCategoryId { get; init; }

    public required string ExperienceCategoryName { get; init; }

    public required int CityId { get; init; }

    public required string CityName { get; init; }

    public required string CountryName { get; init; }

    public required string MeetingPoint { get; init; }

    public required decimal Latitude { get; init; }

    public required decimal Longitude { get; init; }

    public required int DurationMinutes { get; init; }

    public required decimal PricePerPerson { get; init; }

    public required bool IsActive { get; init; }

    public required int? CoverPhotoId { get; init; }

    public required decimal? AverageRating { get; init; }

    public required int ReviewCount { get; init; }

    public required bool IsFavorite { get; init; }

    public required DateTime CreatedAt { get; init; }
}
