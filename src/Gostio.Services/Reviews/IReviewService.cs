using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Reviews;

public interface IReviewService
{
    Task<PagedResult<ReviewResponse>> SearchAsync(
        ReviewSearchRequest search,
        CancellationToken cancellationToken);

    Task<ReviewResponse> GetAsync(int reservationId, CancellationToken cancellationToken);

    Task<ReviewResponse> WriteAsync(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken);

    Task<ReviewResponse> UpdateAsync(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken);

    Task DeleteAsync(int reservationId, CancellationToken cancellationToken);
}
