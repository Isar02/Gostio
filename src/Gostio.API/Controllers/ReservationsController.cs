using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reservations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reservations")]
[Authorize]
public sealed class ReservationsController(
    IReservationService reservations,
    IReservationMoveService moves) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<ReservationResponse>> Search(
        [FromQuery] ReservationSearchRequest search,
        CancellationToken cancellationToken) =>
        reservations.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<ReservationResponse> Get(int id, CancellationToken cancellationToken) =>
        reservations.GetAsync(id, cancellationToken);

    [HttpPost]
    public async Task<ActionResult<ReservationResponse>> Create(
        ReservationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var created = await reservations.CreateAsync(request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [HttpPost("{id:int}/confirm")]
    public Task<ReservationResponse> Confirm(int id, CancellationToken cancellationToken) =>
        moves.ConfirmAsync(id, cancellationToken);

    [HttpPost("{id:int}/cancel")]
    public Task<ReservationResponse> Cancel(
        int id,
        ReservationCancelRequest request,
        CancellationToken cancellationToken) =>
        moves.CancelAsync(id, request, cancellationToken);
}
