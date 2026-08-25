using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reviews;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reviews")]
[Authorize]
public sealed class ReviewsController(IReviewService reviews) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<ReviewResponse>> Search(
        [FromQuery] ReviewSearchRequest search,
        CancellationToken cancellationToken) =>
        reviews.SearchAsync(search, cancellationToken);
}
