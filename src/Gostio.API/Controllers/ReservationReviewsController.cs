using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reviews;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reservations/{reservationId:int}/review")]
[Authorize]
public sealed class ReservationReviewsController(IReviewService reviews) : ControllerBase
{
    [HttpGet]
    public Task<ReviewResponse> Get(int reservationId, CancellationToken cancellationToken) =>
        reviews.GetAsync(reservationId, cancellationToken);

    [HttpPost]
    public async Task<ActionResult<ReviewResponse>> Write(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var written = await reviews.WriteAsync(reservationId, request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { reservationId }, written);
    }

    [HttpPut]
    public Task<ReviewResponse> Update(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken) =>
        reviews.UpdateAsync(reservationId, request, cancellationToken);

    [HttpDelete]
    public async Task<IActionResult> Delete(int reservationId, CancellationToken cancellationToken)
    {
        await reviews.DeleteAsync(reservationId, cancellationToken);

        return NoContent();
    }
}
