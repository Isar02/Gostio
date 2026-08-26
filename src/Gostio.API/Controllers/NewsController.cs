using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.News;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/news")]
[Authorize]
public sealed class NewsController(INewsService news) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<NewsResponse>> Search(
        [FromQuery] NewsSearchRequest search,
        CancellationToken cancellationToken) =>
        news.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<NewsResponse> Get(int id, CancellationToken cancellationToken) =>
        news.GetAsync(id, cancellationToken);

    [HttpGet("{id:int}/image")]
    public async Task<IActionResult> Image(int id, CancellationToken cancellationToken)
    {
        var image = await news.GetImageAsync(id, cancellationToken);

        return File(image.Content, image.ContentType);
    }
}
