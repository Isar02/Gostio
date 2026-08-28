namespace Gostio.Model.Responses;

public sealed class ListingReportRow
{
    public required int CityId { get; init; }

    public required string City { get; init; }

    public required int CategoryId { get; init; }

    public required string Category { get; init; }

    public required int ListingsPublished { get; init; }

    public required int Bookings { get; init; }

    public required int UnitsSold { get; init; }

    public required decimal GrossCharged { get; init; }

    public required decimal? AverageRating { get; init; }

    public required int ReviewCount { get; init; }
}
