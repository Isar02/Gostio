using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reports;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize(Roles = RoleNames.Administrator)]
public sealed class ReportsController(IReportService reports) : ControllerBase
{
    [HttpGet("revenue")]
    public Task<RevenueReportResponse> Revenue(
        [FromQuery] ReportRangeRequest request,
        CancellationToken cancellationToken) =>
        reports.RevenueAsync(request, cancellationToken);
}
