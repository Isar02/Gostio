namespace Gostio.Model.Responses;

public sealed class RevenueReportResponse
{
    public required DateOnly From { get; init; }

    public required DateOnly To { get; init; }

    public required string Currency { get; init; }

    public required IReadOnlyList<RevenueReportRow> Rows { get; init; }

    public required RevenueReportTotals Totals { get; init; }
}
