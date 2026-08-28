using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Configuration;

namespace Gostio.Services.Reports;

internal sealed class ReportService(StripeSettings stripe, RevenueReport revenue) : IReportService
{
    public Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        revenue.BuildAsync(ReportRange.Require(request), stripe.Currency, cancellationToken);
}
