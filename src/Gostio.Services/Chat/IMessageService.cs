using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Chat;

public interface IMessageService
{
    Task<PagedResult<MessageResponse>> SearchAsync(
        int conversationId,
        PagedRequest paging,
        CancellationToken cancellationToken);

    Task<MessageResponse> SendAsync(
        int conversationId,
        MessageSendRequest request,
        CancellationToken cancellationToken);

    Task<UnreadCountResponse> MarkReadAsync(
        int conversationId,
        CancellationToken cancellationToken);

    // The kind narrows it the way it narrows the list, so a panel showing one
    // kind is not counted over both.
    Task<UnreadCountResponse> UnreadAsync(
        ConversationType? type,
        CancellationToken cancellationToken);
}
