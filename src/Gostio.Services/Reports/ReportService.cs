using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Configuration;

namespace Gostio.Services.Reports;

internal sealed class ReportService(
    StripeSettings stripe,
    RevenueReport revenue,
    ListingReport listings)
    : IReportService
{
    public Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        revenue.BuildAsync(ReportRange.Require(request), stripe.Currency, cancellationToken);

    public Task<ListingReportResponse> ListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken) =>
        listings.BuildAsync(
            ReportRange.Require(request),
            Asked(request.Target),
            stripe.Currency,
            cancellationToken);

    private static SearchTarget Asked(SearchTarget? target) =>
        target is SearchTarget named && Enum.IsDefined(named)
            ? named
            : throw new ValidationException(
                nameof(ListingReportRequest.Target),
                "Say which catalogue the report covers.");
}
