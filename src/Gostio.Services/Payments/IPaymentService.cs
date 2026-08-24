using Gostio.Model.Responses;

namespace Gostio.Services.Payments;

public interface IPaymentService
{
    Task<PaymentResponse> StartAsync(int reservationId, CancellationToken cancellationToken);

    Task<PaymentResponse> GetAsync(int reservationId, CancellationToken cancellationToken);
}
