using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.HostVerification;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/host-verification-requests")]
[Authorize]
public sealed class HostVerificationRequestsController(IHostVerificationService requests)
    : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<HostVerificationRequestResponse>> Search(
        [FromQuery] HostVerificationSearchRequest search,
        CancellationToken cancellationToken) =>
        requests.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<HostVerificationRequestResponse> Get(int id, CancellationToken cancellationToken) =>
        requests.GetAsync(id, cancellationToken);

    [HttpPost]
    public async Task<ActionResult<HostVerificationRequestResponse>> Apply(
        CancellationToken cancellationToken)
    {
        var applied = await requests.ApplyAsync(cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = applied.Id }, applied);
    }

    // A decision may carry a reason and an approval usually carries none, so
    // the body is allowed to be absent rather than sent empty to satisfy it.
    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPost("{id:int}/approve")]
    public Task<HostVerificationRequestResponse> Approve(
        int id,
        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)]
        HostVerificationDecisionRequest? request,
        CancellationToken cancellationToken) =>
        requests.ApproveAsync(id, request ?? new(), cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPost("{id:int}/reject")]
    public Task<HostVerificationRequestResponse> Reject(
        int id,
        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)]
        HostVerificationDecisionRequest? request,
        CancellationToken cancellationToken) =>
        requests.RejectAsync(id, request ?? new(), cancellationToken);
}
