namespace Gostio.Services.Reports;

internal interface IListingReportSource
{
    Task<IReadOnlyList<ListingTally>> PublishedAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<BookingTally>> BookingsAsync(
        ReportRange range,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ChargeTally>> ChargesAsync(
        ReportRange range,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<ReviewTally>> ReviewsAsync(
        ReportRange range,
        CancellationToken cancellationToken);
}
