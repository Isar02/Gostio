using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reservations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reservations")]
[Authorize]
public sealed class ReservationsController(IReservationService reservations) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<ReservationResponse>> Create(
        ReservationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var created = await reservations.CreateAsync(request, cancellationToken);

        return Created($"/api/reservations/{created.Id}", created);
    }
}
