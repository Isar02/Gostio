using Gostio.Model.Responses;

namespace Gostio.Services.Chat;

public interface IChatBroadcast
{
    Task MessageSentAsync(MessageResponse message, CancellationToken cancellationToken);
}
