using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reports;

namespace Gostio.Tests.Reports;

internal sealed class StubReports : IReportService
{
    public ReportRangeRequest? LastRange { get; private set; }

    public ListingReportRequest? LastListings { get; private set; }

    public bool AskedForMine { get; private set; }

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

    public Task<RevenueReportResponse> MyRevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken)
    {
        AskedForMine = true;

        return RevenueAsync(request, cancellationToken);
    }

    public Task<ListingReportResponse> MyListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken)
    {
        AskedForMine = true;

        return ListingsAsync(request, cancellationToken);
    }

    public Task<ListingReportResponse> ListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken)
    {
        LastListings = request;

        return Task.FromResult(new ListingReportResponse
        {
            From = request.From ?? default,
            To = request.To ?? default,
            Target = request.Target ?? SearchTarget.Accommodations,
            Currency = "eur",
            Rows = [],
            Totals = new ListingReportTotals
            {
                ListingsPublished = 0,
                Bookings = 0,
                UnitsSold = 0,
                GrossCharged = 0m,
                AverageRating = null,
                ReviewCount = 0,
            },
        });
    }
}
