using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;

namespace Gostio.Services.Reports;

internal sealed class ReportService(
    StripeSettings stripe,
    ICurrentUser currentUser,
    RevenueReport revenue,
    ListingReport listings)
    : IReportService
{
    public Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        RevenueAsync(request, ReportScope.Platform, cancellationToken);

    public Task<ListingReportResponse> ListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken) =>
        ListingsAsync(request, ReportScope.Platform, cancellationToken);

    public Task<RevenueReportResponse> MyRevenueAsync(
        ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        RevenueAsync(request, Mine(), cancellationToken);

    public Task<ListingReportResponse> MyListingsAsync(
        ListingReportRequest request,
        CancellationToken cancellationToken) =>
        ListingsAsync(request, Mine(), cancellationToken);

    private Task<RevenueReportResponse> RevenueAsync(
        ReportRangeRequest request,
        ReportScope scope,
        CancellationToken cancellationToken) =>
        revenue.BuildAsync(
            ReportRange.Require(request), scope, stripe.Currency, cancellationToken);

    private Task<ListingReportResponse> ListingsAsync(
        ListingReportRequest request,
        ReportScope scope,
        CancellationToken cancellationToken) =>
        listings.BuildAsync(
            ReportRange.Require(request),
            Asked(request.Target),
            scope,
            stripe.Currency,
            cancellationToken);

    private ReportScope Mine() => new(currentUser.RequireUserId());

    private static SearchTarget Asked(SearchTarget? target) =>
        target is SearchTarget named && Enum.IsDefined(named)
            ? named
            : throw new ValidationException(
                nameof(ListingReportRequest.Target),
                "Say which catalogue the report covers.");
}
