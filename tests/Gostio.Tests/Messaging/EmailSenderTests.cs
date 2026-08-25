using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Messaging;

public class EmailSenderTests
{
    // A worker that quietly sent nothing looks like one with nothing to send.
    [Fact]
    public async Task MailCannotBeSentBeforeSmtpIsConfigured()
    {
        await using var provider = Consumers(Smtp(host: "", from: ""));

        var failure = await Assert.ThrowsAsync<PermanentMessageFailure>(() =>
            provider.GetRequiredService<IEmailSender>().SendAsync(Anything(), default));

        Assert.Contains("SMTP_HOST", failure.Message, StringComparison.Ordinal);
        Assert.Contains("SMTP_FROM_EMAIL", failure.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void AnAddressAloneIsNotEnoughToSendFrom()
    {
        Assert.False(Smtp(host: "smtp.example.com", from: "").IsConfigured);
        Assert.False(Smtp(host: "", from: "gostio@example.com").IsConfigured);
        Assert.True(Smtp(host: "smtp.example.com", from: "gostio@example.com").IsConfigured);
    }

    private static ServiceProvider Consumers(SmtpSettings smtp)
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddSingleton(smtp);
        services.AddGostioMessageConsumers();

        return services.BuildServiceProvider();
    }

    private static SmtpSettings Smtp(string host, string from) => new()
    {
        Host = host,
        Port = 587,
        Username = "",
        Password = "",
        UseSsl = true,
        FromEmail = from,
        FromName = "Gostio",
    };

    private static EmailMessage Anything() => new()
    {
        ToEmail = "guest@example.com",
        ToName = "A Guest",
        Subject = "Anything",
        Body = "Anything at all.",
    };
}
