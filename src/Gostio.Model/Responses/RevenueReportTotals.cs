namespace Gostio.Model.Responses;

public sealed class RevenueReportTotals
{
    public required int BookingsCreated { get; init; }

    public required int BookingsCompleted { get; init; }

    public required decimal GrossCharged { get; init; }

    public required decimal Refunded { get; init; }

    public required decimal Net { get; init; }
}
