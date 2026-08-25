using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.HostVerification;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

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
}
