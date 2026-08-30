using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reports;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize]
public sealed class ReportsController(IReportService reports) : ControllerBase
{
    // The role sits on each action rather than on the class, because the two
    // families answer to different ones and attributes at both levels are read
    // together rather than the nearer one winning. Every action names its own.
    [Authorize(Roles = RoleNames.Administrator)]
    [HttpGet("revenue")]
    public Task<RevenueReportResponse> Revenue(
        [FromQuery] ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        reports.RevenueAsync(request, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpGet("listings")]
    public Task<ListingReportResponse> Listings(
        [FromQuery] ListingReportRequest request,
        CancellationToken cancellationToken) =>
        reports.ListingsAsync(request, cancellationToken);

    [Authorize(Roles = RoleNames.Host)]
    [HttpGet("mine/revenue")]
    public Task<RevenueReportResponse> MyRevenue(
        [FromQuery] ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        reports.MyRevenueAsync(request, cancellationToken);

    [Authorize(Roles = RoleNames.Host)]
    [HttpGet("mine/listings")]
    public Task<ListingReportResponse> MyListings(
        [FromQuery] ListingReportRequest request,
        CancellationToken cancellationToken) =>
        reports.MyListingsAsync(request, cancellationToken);
}
