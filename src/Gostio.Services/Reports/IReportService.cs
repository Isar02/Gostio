using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Reports;

public interface IReportService
{
    Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken);
}
