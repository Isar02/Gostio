using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Recommendations;

public interface IRecommendationService
{
    Task<PagedResult<RecommendationResponse>> SearchAsync(
        RecommendationSearchRequest search,
        CancellationToken cancellationToken);
}
