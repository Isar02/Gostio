using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodations/{accommodationId:int}/availability")]
[Authorize]
public sealed class AccommodationAvailabilityController(IAccommodationAvailabilityService ranges)
    : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<AccommodationAvailabilityResponse>> Search(
        int accommodationId,
        [FromQuery] AccommodationAvailabilitySearchRequest search,
        CancellationToken cancellationToken) =>
        ranges.SearchAsync(accommodationId, search, cancellationToken);

    [HttpGet("{availabilityId:int}")]
    public Task<AccommodationAvailabilityResponse> Get(
        int accommodationId,
        int availabilityId,
        CancellationToken cancellationToken) =>
        ranges.GetAsync(accommodationId, availabilityId, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPost]
    public async Task<ActionResult<AccommodationAvailabilityResponse>> Add(
        int accommodationId,
        AccommodationAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        var added = await ranges.AddAsync(accommodationId, request, cancellationToken);

        return CreatedAtAction(
            nameof(Get),
            new { accommodationId, availabilityId = added.Id },
            added);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpDelete("{availabilityId:int}")]
    public async Task<IActionResult> Delete(
        int accommodationId,
        int availabilityId,
        CancellationToken cancellationToken)
    {
        await ranges.DeleteAsync(accommodationId, availabilityId, cancellationToken);

        return NoContent();
    }
}
