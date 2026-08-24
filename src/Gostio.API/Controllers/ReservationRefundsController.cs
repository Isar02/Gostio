using Gostio.Model.Responses;
using Gostio.Services.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reservations/{reservationId:int}/refund")]
[Authorize]
public sealed class ReservationRefundsController(IRefundService refunds) : ControllerBase
{
    [HttpGet]
    public Task<RefundResponse> Get(int reservationId, CancellationToken cancellationToken) =>
        refunds.GetAsync(reservationId, cancellationToken);

    // Answers whether or not anything was ever charged, so a guest is told what
    // calling a booking off costs while calling it off is still a choice.
    [HttpGet("quote")]
    public Task<RefundQuoteResponse> Quote(
        int reservationId,
        CancellationToken cancellationToken) =>
        refunds.QuoteAsync(reservationId, cancellationToken);
}
