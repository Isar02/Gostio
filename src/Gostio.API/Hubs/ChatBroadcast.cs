using Gostio.Model.Responses;
using Gostio.Services.Chat;
using Microsoft.AspNetCore.SignalR;

namespace Gostio.API.Hubs;

// A delivery never fails what raised it: a message is written whether or not
// anybody is listening, and a hub that cannot reach a connection is not the
// sender's problem.
internal sealed class ChatBroadcast(
    IHubContext<ChatHub> hub,
    ILogger<ChatBroadcast> logger) : IChatBroadcast
{
    public const string MessageSent = "MessageSent";

    public async Task MessageSentAsync(MessageResponse message, CancellationToken cancellationToken)
    {
        try
        {
            await hub.Clients
                .Group(ChatGroups.Of(message.ConversationId))
                .SendAsync(MessageSent, message, cancellationToken);
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(
                failure,
                "Message {MessageId} was written but never left the hub.",
                message.Id);
        }
    }
}
