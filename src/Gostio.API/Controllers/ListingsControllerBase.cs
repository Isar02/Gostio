using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[Authorize]
public abstract class ListingsControllerBase<TService, TResponse, TSearch, TCreate, TUpdate>(
    TService service) : ControllerBase
    where TService : ICrudService<TResponse, TSearch, TCreate, TUpdate>
    where TResponse : IIdentified
    where TSearch : ListingSearchRequest
{
    [HttpGet]
    public Task<PagedResult<TResponse>> Search(
        [FromQuery] TSearch search,
        CancellationToken cancellationToken) =>
        service.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<TResponse> Get(int id, CancellationToken cancellationToken) =>
        service.GetAsync(id, cancellationToken);

    // The attribute says who may write at all; whose listing this one is, is a
    // question about the row, so the service answers that half.
    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPost]
    public async Task<ActionResult<TResponse>> Create(
        TCreate request,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateAsync(request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut("{id:int}")]
    public Task<TResponse> Update(int id, TUpdate request, CancellationToken cancellationToken) =>
        service.UpdateAsync(id, request, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await service.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
