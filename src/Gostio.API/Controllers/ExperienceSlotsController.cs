using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/experiences/{experienceId:int}/slots")]
[Authorize]
public sealed class ExperienceSlotsController(IExperienceSlotService slots) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<ExperienceSlotResponse>> Search(
        int experienceId,
        [FromQuery] ExperienceSlotSearchRequest search,
        CancellationToken cancellationToken) =>
        slots.SearchAsync(experienceId, search, cancellationToken);

    [HttpGet("{slotId:int}")]
    public Task<ExperienceSlotResponse> Get(
        int experienceId,
        int slotId,
        CancellationToken cancellationToken) =>
        slots.GetAsync(experienceId, slotId, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPost]
    public async Task<ActionResult<ExperienceSlotResponse>> Add(
        int experienceId,
        ExperienceSlotCreateRequest request,
        CancellationToken cancellationToken)
    {
        var added = await slots.AddAsync(experienceId, request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { experienceId, slotId = added.Id }, added);
    }

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpPut("{slotId:int}")]
    public Task<ExperienceSlotResponse> Update(
        int experienceId,
        int slotId,
        ExperienceSlotUpdateRequest request,
        CancellationToken cancellationToken) =>
        slots.UpdateAsync(experienceId, slotId, request, cancellationToken);

    [Authorize(Roles = RoleNames.HostOrAdministrator)]
    [HttpDelete("{slotId:int}")]
    public async Task<IActionResult> Delete(
        int experienceId,
        int slotId,
        CancellationToken cancellationToken)
    {
        await slots.DeleteAsync(experienceId, slotId, cancellationToken);

        return NoContent();
    }
}
