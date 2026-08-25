using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/conversations")]
[Authorize]
public sealed class ConversationsController(IConversationService conversations) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<ConversationResponse>> Search(
        [FromQuery] ConversationSearchRequest search,
        CancellationToken cancellationToken) =>
        conversations.SearchAsync(search, cancellationToken);

    [HttpGet("{id:int}")]
    public Task<ConversationResponse> Get(int id, CancellationToken cancellationToken) =>
        conversations.GetAsync(id, cancellationToken);

    // Opening a thread that already stands answers with it rather than refusing,
    // so a client may ask without first knowing whether it exists.
    [HttpPost]
    public async Task<ActionResult<ConversationResponse>> Open(
        ConversationOpenRequest request,
        CancellationToken cancellationToken)
    {
        var opened = await conversations.OpenAsync(request, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = opened.Id }, opened);
    }

    [HttpPost("support")]
    public async Task<ActionResult<ConversationResponse>> OpenSupport(
        CancellationToken cancellationToken)
    {
        var opened = await conversations.OpenSupportAsync(cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = opened.Id }, opened);
    }
}
