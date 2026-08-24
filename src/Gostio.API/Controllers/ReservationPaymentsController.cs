using Gostio.Model.Responses;
using Gostio.Services.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reservations/{reservationId:int}/payment")]
[Authorize]
public sealed class ReservationPaymentsController(IPaymentService payments) : ControllerBase
{
    [HttpGet]
    public Task<PaymentResponse> Get(int reservationId, CancellationToken cancellationToken) =>
        payments.GetAsync(reservationId, cancellationToken);

    // Repeatable on purpose: a guest who closed the card sheet asks again and
    // is handed back the same charge rather than a second one.
    [HttpPost]
    public Task<PaymentResponse> Start(int reservationId, CancellationToken cancellationToken) =>
        payments.StartAsync(reservationId, cancellationToken);
}
