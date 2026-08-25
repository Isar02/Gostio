using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Chat;

public interface IConversationService
{
    Task<PagedResult<ConversationResponse>> SearchAsync(
        ConversationSearchRequest search,
        CancellationToken cancellationToken);

    Task<ConversationResponse> GetAsync(int conversationId, CancellationToken cancellationToken);
}
