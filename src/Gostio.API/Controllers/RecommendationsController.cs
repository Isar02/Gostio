using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Recommendations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/recommendations")]
[Authorize]
public sealed class RecommendationsController(IRecommendationService recommendations)
    : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<RecommendationResponse>> Search(
        [FromQuery] RecommendationSearchRequest search,
        CancellationToken cancellationToken) =>
        recommendations.SearchAsync(search, cancellationToken);
}
