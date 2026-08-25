using Gostio.Services.Messaging;

namespace Gostio.IntegrationTests;

// The broker's place in a test: kept in a list, no socket opened.
public sealed class CapturedNotices : INotices
{
    private readonly List<object> sent = [];

    public IReadOnlyList<object> Sent => sent;

    public IEnumerable<TMessage> Of<TMessage>() => sent.OfType<TMessage>();

    public Task SendAsync<TMessage>(TMessage message, CancellationToken cancellationToken)
        where TMessage : class
    {
        sent.Add(message);

        return Task.CompletedTask;
    }
}
