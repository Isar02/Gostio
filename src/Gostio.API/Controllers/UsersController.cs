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

    // No role attribute: self or administrator is a question about the row,
    // so the service answers it.
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
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await users.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
