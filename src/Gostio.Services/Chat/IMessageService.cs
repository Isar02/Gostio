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

    Task<UnreadCountResponse> UnreadAsync(CancellationToken cancellationToken);
}
