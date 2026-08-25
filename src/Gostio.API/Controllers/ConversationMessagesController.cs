using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/conversations")]
[Authorize]
public sealed class ConversationMessagesController(IMessageService messages) : ControllerBase
{
    [HttpGet("{conversationId:int}/messages")]
    public Task<PagedResult<MessageResponse>> Search(
        int conversationId,
        [FromQuery] PagedRequest paging,
        CancellationToken cancellationToken) =>
        messages.SearchAsync(conversationId, paging, cancellationToken);

    [HttpPost("{conversationId:int}/messages")]
    public Task<MessageResponse> Send(
        int conversationId,
        MessageSendRequest request,
        CancellationToken cancellationToken) =>
        messages.SendAsync(conversationId, request, cancellationToken);

    [HttpPost("{conversationId:int}/read")]
    public Task<UnreadCountResponse> MarkRead(
        int conversationId,
        CancellationToken cancellationToken) =>
        messages.MarkReadAsync(conversationId, cancellationToken);

    // Polled or refreshed, so it costs a count rather than a page of threads.
    [HttpGet("unread-count")]
    public Task<UnreadCountResponse> Unread(CancellationToken cancellationToken) =>
        messages.UnreadAsync(cancellationToken);
}
