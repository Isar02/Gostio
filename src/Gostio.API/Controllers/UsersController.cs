using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/users")]
[Authorize]
public sealed class UsersController(IUserService users) : ControllerBase
{
    [Authorize(Roles = RoleNames.Administrator)]
    [HttpGet]
    public Task<PagedResult<UserResponse>> Search(
        [FromQuery] UserSearchRequest search,
        CancellationToken cancellationToken) =>
        users.SearchAsync(search, cancellationToken);

    [HttpGet("me")]
    public Task<UserResponse> Mine(CancellationToken cancellationToken) =>
        users.GetMineAsync(cancellationToken);

    [HttpPut("me")]
    public Task<UserResponse> UpdateMine(
        UserUpdateRequest request,
        CancellationToken cancellationToken) =>
        users.UpdateMineAsync(request, cancellationToken);

    [RequestSizeLimit(UploadLimits.Multipart)]
    [HttpPut("me/image")]
    public async Task<UserResponse> SetMineImage(
        [FromForm] ImageFileUpload upload,
        CancellationToken cancellationToken) =>
        await users.SetMineImageAsync(
            await upload.File.ToImageUploadAsync(cancellationToken), cancellationToken);

    [HttpDelete("me/image")]
    public async Task<IActionResult> ClearMineImage(CancellationToken cancellationToken)
    {
        await users.ClearMineImageAsync(cancellationToken);

        return NoContent();
    }

    // The one route under an id that is not an administrator's: a host's
    // picture stands beside their listings and a participant's beside their
    // messages, so anybody signed in has to be able to fetch one.
    [HttpGet("{id:int}/image")]
    public async Task<IActionResult> Image(int id, CancellationToken cancellationToken)
    {
        var image = await users.GetImageAsync(id, cancellationToken);

        return File(image.Content, image.ContentType);
    }

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpGet("{id:int}")]
    public Task<UserResponse> Get(int id, CancellationToken cancellationToken) =>
        users.GetAsync(id, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPost]
    public async Task<ActionResult<UserResponse>> Create(
        UserCreateRequest request,
        CancellationToken cancellationToken)
    {
        var created = await users.CreateAsync(request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPut("{id:int}")]
    public Task<UserResponse> Update(
        int id,
        UserUpdateRequest request,
        CancellationToken cancellationToken) =>
        users.UpdateAsync(id, request, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPut("{id:int}/roles")]
    public Task<UserResponse> SetRoles(
        int id,
        UserRolesRequest request,
        CancellationToken cancellationToken) =>
        users.SetRolesAsync(id, request, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPut("{id:int}/state")]
    public Task<UserResponse> SetState(
        int id,
        UserStateRequest request,
        CancellationToken cancellationToken) =>
        users.SetStateAsync(id, request, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [RequestSizeLimit(UploadLimits.Multipart)]
    [HttpPut("{id:int}/image")]
    public async Task<UserResponse> SetImage(
        int id,
        [FromForm] ImageFileUpload upload,
        CancellationToken cancellationToken) =>
        await users.SetImageAsync(
            id, await upload.File.ToImageUploadAsync(cancellationToken), cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpDelete("{id:int}/image")]
    public async Task<IActionResult> ClearImage(int id, CancellationToken cancellationToken)
    {
        await users.ClearImageAsync(id, cancellationToken);

        return NoContent();
    }

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await users.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
