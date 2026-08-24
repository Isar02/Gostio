using Gostio.Model.Responses;

namespace Gostio.Services.Payments;

public interface IRefundService
{
    Task<RefundQuoteResponse> QuoteAsync(int reservationId, CancellationToken cancellationToken);

    Task<RefundResponse> GetAsync(int reservationId, CancellationToken cancellationToken);
}
