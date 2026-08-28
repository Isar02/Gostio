using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reports;

namespace Gostio.Tests.Reports;

internal sealed class StubReports : IReportService
{
    public ReportRangeRequest? LastRange { get; private set; }

    public Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken)
    {
        LastRange = request;

        return Task.FromResult(new RevenueReportResponse
        {
            From = request.From ?? default,
            To = request.To ?? default,
            Currency = "eur",
            Rows = [],
            Totals = new RevenueReportTotals
            {
                BookingsCreated = 0,
                BookingsCompleted = 0,
                GrossCharged = 0m,
                Refunded = 0m,
                Net = 0m,
            },
        });
    }
}
