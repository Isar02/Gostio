namespace Gostio.Services.Payments;

public interface IPaymentWebhook
{
    Task ReceiveAsync(string payload, string? signature, CancellationToken cancellationToken);
}
