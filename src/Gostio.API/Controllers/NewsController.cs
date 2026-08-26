using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
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

    [Authorize(Roles = RoleNames.Administrator)]
    [RequestSizeLimit(UploadLimits.Multipart)]
    [HttpPost]
    public async Task<ActionResult<NewsResponse>> Write(
        [FromForm] NewsCreateUpload upload,
        CancellationToken cancellationToken)
    {
        var written = await news.WriteAsync(
            upload,
            await upload.File.ToImageUploadAsync(cancellationToken),
            cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = written.Id }, written);
    }

    [Authorize(Roles = RoleNames.Administrator)]
    [RequestSizeLimit(UploadLimits.Multipart)]
    [HttpPut("{id:int}")]
    public async Task<NewsResponse> Update(
        int id,
        [FromForm] NewsUpdateUpload upload,
        CancellationToken cancellationToken) =>
        await news.UpdateAsync(
            id,
            upload,
            upload.File is null ? null : await upload.File.ToImageUploadAsync(cancellationToken),
            cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await news.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
