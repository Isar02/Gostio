using Gostio.Model.Enums;

namespace Gostio.Model.Responses;

public sealed class RecommendationResponse
{
    public required int ListingId { get; init; }

    public required SearchTarget Target { get; init; }

    public required string Title { get; init; }

    public required string CityName { get; init; }

    public required string CountryName { get; init; }

    public required string CategoryName { get; init; }

    public required decimal Price { get; init; }

    public required int? CoverPhotoId { get; init; }

    public required decimal? AverageRating { get; init; }

    public required int ReviewCount { get; init; }

    public required double Score { get; init; }

    public required IReadOnlyList<RecommendationReasonResponse> Reasons { get; init; }
}
