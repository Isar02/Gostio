namespace Gostio.Model.Responses;

public sealed class RevenueReportRow
{
    public required int Year { get; init; }

    public required int Month { get; init; }

    public required int BookingsCreated { get; init; }

    public required int BookingsCompleted { get; init; }

    public required decimal GrossCharged { get; init; }

    public required decimal Refunded { get; init; }

    public required decimal Net { get; init; }
}
