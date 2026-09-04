using Gostio.Model.Messaging;

namespace Gostio.Services.Messaging;

public interface INotices
{
    // Answers whether the broker took it, so a caller that has a second notice
    // riding on the first can tell. Nothing is thrown either way.
    Task<bool> SendAsync<TMessage>(TMessage message, CancellationToken cancellationToken)
        where TMessage : class;

    // The push follows the row and never leads it: the row is the record, and a
    // tap on the phone that no list can account for is worse than no tap at
    // all. Written here rather than at the call sites so that neither of them
    // can raise one without the other, and so a stand-in cannot forget it.
    async Task NotifyAsync(NotificationMessage notice, CancellationToken cancellationToken)
    {
        if (await SendAsync(notice, cancellationToken))
        {
            await SendAsync(PushMessage.Of(notice), cancellationToken);
        }
    }
}
