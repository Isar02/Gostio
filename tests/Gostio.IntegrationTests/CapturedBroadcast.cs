using Gostio.Model.Responses;
using Gostio.Services.Chat;

namespace Gostio.IntegrationTests;

// The hub takes no part in a test; what would have been delivered is kept.
internal sealed class CapturedBroadcast : IChatBroadcast
{
    private readonly List<MessageResponse> delivered = [];

    public IReadOnlyList<MessageResponse> Delivered => delivered;

    public Task MessageSentAsync(MessageResponse message, CancellationToken cancellationToken)
    {
        delivered.Add(message);

        return Task.CompletedTask;
    }
}
