using Gostio.Model.Enums;

namespace Gostio.Model.Responses;

public sealed class ListingReportResponse
{
    public required DateOnly From { get; init; }

    public required DateOnly To { get; init; }

    public required SearchTarget Target { get; init; }

    public required string Currency { get; init; }

    public required IReadOnlyList<ListingReportRow> Rows { get; init; }

    public required ListingReportTotals Totals { get; init; }
}
