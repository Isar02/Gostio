using Gostio.Model.Messaging;

namespace Gostio.Services.Messaging;

public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken);
}
