using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Reports;

public interface IReportService
{
    Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken);

    Task<ListingReportResponse> ListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken);

    Task<RevenueReportResponse> MyRevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken);

    Task<ListingReportResponse> MyListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken);
}
