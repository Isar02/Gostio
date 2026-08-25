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
}
