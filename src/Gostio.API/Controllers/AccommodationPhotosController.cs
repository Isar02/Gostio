using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodations/{accommodationId:int}/photos")]
[Authorize]
public sealed class AccommodationPhotosController(IAccommodationPhotoService photos)
    : ControllerBase
{
    // Boundaries and headers travel with the image, so the ceiling sits above
    // it. This one is refused before a body is read, which the check in the
    // service cannot be.
    private const int UploadLimit = ImageRules.MaximumBytes + (8 * 1024);

    [HttpGet]
    public Task<PagedResult<AccommodationPhotoResponse>> Search(
        int accommodationId,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        photos.SearchAsync(accommodationId, request, cancellationToken);

    [HttpGet("{photoId:int}")]
    public Task<AccommodationPhotoResponse> Get(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken) =>
        photos.GetAsync(accommodationId, photoId, cancellationToken);

    [HttpGet("{photoId:int}/content")]
    public async Task<IActionResult> Content(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken)
    {
        var image = await photos.GetContentAsync(accommodationId, photoId, cancellationToken);

        return File(image.Content, image.ContentType);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [RequestSizeLimit(UploadLimit)]
    [HttpPost]
    public async Task<ActionResult<AccommodationPhotoResponse>> Upload(
        int accommodationId,
        [FromForm] AccommodationPhotoUpload upload,
        CancellationToken cancellationToken)
    {
        using var buffer = new MemoryStream();

        await upload.File.CopyToAsync(buffer, cancellationToken);

        var created = await photos.AddAsync(
            accommodationId,
            new ImageUpload(buffer.ToArray(), upload.File.ContentType),
            cancellationToken);

        return CreatedAtAction(
            nameof(Get),
            new { accommodationId, photoId = created.Id },
            created);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut("{photoId:int}/cover")]
    public Task<AccommodationPhotoResponse> SetCover(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken) =>
        photos.SetCoverAsync(accommodationId, photoId, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpDelete("{photoId:int}")]
    public async Task<IActionResult> Delete(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await photos.DeleteAsync(accommodationId, photoId, cancellationToken);

        return NoContent();
    }
}
