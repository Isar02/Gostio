namespace Gostio.Services.Reports;

internal interface IListingReportSource
{
    Task<IReadOnlyList<ListingTally>> PublishedAsync(
        ReportScope scope,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<BookingTally>> BookingsAsync(
        ReportRange range,
        ReportScope scope,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ChargeTally>> ChargesAsync(
        ReportRange range,
        ReportScope scope,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ReviewTally>> ReviewsAsync(
        ReportRange range,
        ReportScope scope,
        CancellationToken cancellationToken);
}
