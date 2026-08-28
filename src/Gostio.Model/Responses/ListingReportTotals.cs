namespace Gostio.Model.Responses;

public sealed class ListingReportTotals
{
    public required int ListingsPublished { get; init; }

    public required int Bookings { get; init; }

    public required int UnitsSold { get; init; }

    public required decimal GrossCharged { get; init; }

    public required decimal? AverageRating { get; init; }

    public required int ReviewCount { get; init; }
}
