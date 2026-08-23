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
    // A set rather than a page: it is written whole, so it is read whole.
    [HttpGet]
    public Task<IReadOnlyList<LookupResponse>> Get(
        int accommodationId,
        CancellationToken cancellationToken) =>
        amenities.GetAsync(accommodationId, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut]
    public Task<IReadOnlyList<LookupResponse>> Set(
        int accommodationId,
        AccommodationAmenitiesRequest request,
        CancellationToken cancellationToken) =>
        amenities.SetAsync(accommodationId, request, cancellationToken);
}
