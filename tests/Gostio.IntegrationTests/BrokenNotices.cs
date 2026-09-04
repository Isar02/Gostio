using Gostio.Services.Messaging;

namespace Gostio.IntegrationTests;

// A broker nobody can reach, in the one form a caller must never see.
internal sealed class BrokenNotices : INotices
{
    public Task<bool> SendAsync<TMessage>(TMessage message, CancellationToken cancellationToken)
        where TMessage : class =>
        throw new InvalidOperationException("The broker refused the connection.");
}
