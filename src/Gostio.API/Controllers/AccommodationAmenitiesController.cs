using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodations/{accommodationId:int}/amenities")]
[Authorize]
public sealed class AccommodationAmenitiesController(IAccommodationAmenityService amenities)
    : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<LookupResponse>> Get(
        int accommodationId,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        amenities.GetAsync(accommodationId, request, cancellationToken);

    // The whole set rather than a page of it, because it is the set this call
    // just wrote.
    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut]
    public Task<IReadOnlyList<LookupResponse>> Set(
        int accommodationId,
        AccommodationAmenitiesRequest request,
        CancellationToken cancellationToken) =>
        amenities.SetAsync(accommodationId, request, cancellationToken);
}
