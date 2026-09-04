using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

// The availability endpoint beside this one answers the host's exceptions; this
// answers what a guest may still book, which is those exceptions and the
// bookings together. Reading it is open to anybody signed in, and nothing here
// writes.
[ApiController]
[Route("api/accommodations/{accommodationId:int}/calendar")]
[Authorize]
public sealed class AccommodationCalendarController(IStayCalendarService calendar)
    : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<StayCalendarDayResponse>> Get(
        int accommodationId,
        [FromQuery] StayCalendarRequest request,
        CancellationToken cancellationToken) =>
        calendar.ReadAsync(accommodationId, request, cancellationToken);
}
