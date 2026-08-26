using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[Authorize]
public abstract class ListingPhotosControllerBase<TService>(TService photos) : ControllerBase
    where TService : IListingPhotoService
{
    [HttpGet]
    public Task<PagedResult<ListingPhotoResponse>> Search(
        int listingId,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        photos.SearchAsync(listingId, request, cancellationToken);

    [HttpGet("{photoId:int}")]
    public Task<ListingPhotoResponse> Get(
        int listingId,
        int photoId,
        CancellationToken cancellationToken) =>
        photos.GetAsync(listingId, photoId, cancellationToken);

    [HttpGet("{photoId:int}/content")]
    public async Task<IActionResult> Content(
        int listingId,
        int photoId,
        CancellationToken cancellationToken)
    {
        var image = await photos.GetContentAsync(listingId, photoId, cancellationToken);

        return File(image.Content, image.ContentType);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [RequestSizeLimit(UploadLimits.Multipart)]
    [HttpPost]
    public async Task<ActionResult<ListingPhotoResponse>> Upload(
        int listingId,
        [FromForm] ListingPhotoUpload upload,
        CancellationToken cancellationToken)
    {
        var created = await photos.AddAsync(
            listingId,
            await upload.File.ToImageUploadAsync(cancellationToken),
            cancellationToken);

        return CreatedAtAction(
            nameof(Get),
            new { listingId, photoId = created.Id },
            created);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut("{photoId:int}/cover")]
    public Task<ListingPhotoResponse> SetCover(
        int listingId,
        int photoId,
        CancellationToken cancellationToken) =>
        photos.SetCoverAsync(listingId, photoId, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpDelete("{photoId:int}")]
    public async Task<IActionResult> Delete(
        int listingId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await photos.DeleteAsync(listingId, photoId, cancellationToken);

        return NoContent();
    }
}
