namespace Gostio.Services.Messaging;

public interface INotices
{
    Task SendAsync<TMessage>(TMessage message, CancellationToken cancellationToken)
        where TMessage : class;
}
