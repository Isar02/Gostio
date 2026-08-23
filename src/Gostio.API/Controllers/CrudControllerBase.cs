using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

// Reading a managed table is open to any signed in account, because the
// clients fill their filters from it. Writing to one is not. A derived
// controller adds the route and nothing else.
[Authorize]
public abstract class CrudControllerBase<TService, TResponse, TSearch, TCreate, TUpdate>(
    TService service) : ControllerBase
    where TService : ICrudService<TResponse, TSearch, TCreate, TUpdate>
    where TResponse : IIdentified
    where TSearch : PagedRequest
{
    protected TService Service { get; } = service;

    [HttpGet]
    public Task<PagedResult<TResponse>> Search(
        [FromQuery] TSearch search,
        CancellationToken cancellationToken) =>
        Service.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<TResponse> Get(int id, CancellationToken cancellationToken) =>
        Service.GetAsync(id, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPost]
    public async Task<ActionResult<TResponse>> Create(
        TCreate request,
        CancellationToken cancellationToken)
    {
        var created = await Service.CreateAsync(request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
    }

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpPut("{id:int}")]
    public Task<TResponse> Update(int id, TUpdate request, CancellationToken cancellationToken) =>
        Service.UpdateAsync(id, request, cancellationToken);

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await Service.DeleteAsync(id, cancellationToken);

        return NoContent();
    }
}
