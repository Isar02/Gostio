using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodations")]
[Authorize]
public sealed class AccommodationsController(IAccommodationService accommodations) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<AccommodationResponse>> Search(
        [FromQuery] AccommodationSearchRequest search,
        CancellationToken cancellationToken) =>
        accommodations.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<AccommodationResponse> Get(int id, CancellationToken cancellationToken) =>
        accommodations.GetAsync(id, cancellationToken);

    // The attribute says who may write at all; whose listing this one is, is a
    // question about the row, so the service answers that half.
    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPost]
    public async Task<ActionResult<AccommodationResponse>> Create(
        AccommodationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var created = await accommodations.CreateAsync(request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut("{id:int}")]
    public Task<AccommodationResponse> Update(
        int id,
        AccommodationUpdateRequest request,
        CancellationToken cancellationToken) =>
        accommodations.UpdateAsync(id, request, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await accommodations.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
