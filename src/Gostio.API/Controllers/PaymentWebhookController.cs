using Gostio.Services.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/payments/webhook")]
[AllowAnonymous]
public sealed class PaymentWebhookController(IPaymentWebhook webhook) : ControllerBase
{
    private const string SignatureHeader = "Stripe-Signature";

    // The body is read as it arrived rather than bound to a model: the signature
    // is computed over those exact bytes, and anything that reshapes them on the
    // way in makes every call fail verification.
    [HttpPost]
    public async Task<IActionResult> Receive(CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(Request.Body);

        var payload = await reader.ReadToEndAsync(cancellationToken);

        await webhook.ReceiveAsync(
            payload, Request.Headers[SignatureHeader], cancellationToken);

        return Ok();
    }
}
