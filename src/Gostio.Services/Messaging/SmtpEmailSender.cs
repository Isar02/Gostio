using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;
using MimeKit.Text;

namespace Gostio.Services.Messaging;

internal sealed class SmtpEmailSender(SmtpSettings settings) : IEmailSender
{
    private const int ImplicitSslPort = 465;

    public async Task SendAsync(EmailMessage message, CancellationToken cancellationToken)
    {
        if (!settings.IsConfigured)
        {
            throw new PermanentMessageFailure(
                "Sending mail needs SMTP_HOST and SMTP_FROM_EMAIL in the .env file.");
        }

        using var client = new SmtpClient();

        await client.ConnectAsync(settings.Host, settings.Port, Security(), cancellationToken);

        if (settings.Username.Length > 0)
        {
            await client.AuthenticateAsync(
                settings.Username, settings.Password, cancellationToken);
        }

        await client.SendAsync(Compose(message), cancellationToken);
        await client.DisconnectAsync(quit: true, cancellationToken);
    }

    private MimeMessage Compose(EmailMessage message)
    {
        var mail = new MimeMessage
        {
            Subject = message.Subject,
            Body = new TextPart(TextFormat.Plain) { Text = message.Body },
        };

        mail.From.Add(new MailboxAddress(settings.FromName, settings.FromEmail));
        mail.To.Add(new MailboxAddress(message.ToName, message.ToEmail));

        return mail;
    }

    // Required, not taken if offered: a server without it gets the password.
    private SecureSocketOptions Security() =>
        settings.UseSsl
            ? settings.Port == ImplicitSslPort
                ? SecureSocketOptions.SslOnConnect
                : SecureSocketOptions.StartTls
            : SecureSocketOptions.None;
}
