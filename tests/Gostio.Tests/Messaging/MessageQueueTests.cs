using System.Text.Json;
using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;

namespace Gostio.Tests.Messaging;

public class MessageQueueTests
{
    private static readonly RabbitMqSettings Broker = new()
    {
        Host = "localhost",
        Port = 5672,
        Username = "gostio",
        Password = "gostio",
        VirtualHost = "/",
        EmailQueue = "gostio.email",
        NotificationQueue = "gostio.notifications",
        PushQueue = "gostio.push",
    };

    [Fact]
    public void EachMessageIsCarriedByTheQueueTheSettingsName()
    {
        Assert.Equal(Broker.EmailQueue, MessageQueues.For<EmailMessage>(Broker));
        Assert.Equal(Broker.NotificationQueue, MessageQueues.For<NotificationMessage>(Broker));
        Assert.Equal(Broker.PushQueue, MessageQueues.For<PushMessage>(Broker));
    }

    // Fails where it is written rather than where it is missed.
    [Fact]
    public void AMessageNoQueueCarriesIsRefused()
    {
        var failure = Assert.Throws<InvalidOperationException>(
            () => MessageQueues.For<string>(Broker));

        Assert.Contains(nameof(String), failure.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void EveryQueueAMessageNamesIsOneTheConnectionDeclares() =>
        Assert.All(
            new[]
            {
                MessageQueues.For<EmailMessage>(Broker),
                MessageQueues.For<NotificationMessage>(Broker),
                MessageQueues.For<PushMessage>(Broker),
            },
            queue => Assert.Contains(queue, MessageQueues.Declared(Broker)));

    // Written in one process and read in another.
    [Fact]
    public void AnEmailSurvivesTheQueue()
    {
        var sent = new EmailMessage
        {
            ToEmail = "guest@example.com",
            ToName = "A Guest",
            Subject = "Your booking is confirmed",
            Body = "The host confirmed your stay.",
        };

        var read = RoundTrip(sent);

        Assert.Equal(sent.ToEmail, read.ToEmail);
        Assert.Equal(sent.ToName, read.ToName);
        Assert.Equal(sent.Subject, read.Subject);
        Assert.Equal(sent.Body, read.Body);
    }

    [Fact]
    public void ANotificationSurvivesTheQueue()
    {
        var raised = new NotificationMessage
        {
            UserId = 7,
            Type = NotificationType.PaymentSucceeded,
            ReservationId = 42,
            Title = "Payment received",
            Body = "We have taken the payment for your booking.",
            CreatedAt = new DateTime(2026, 6, 1, 12, 0, 0, DateTimeKind.Utc),
        };

        var read = RoundTrip(raised);

        Assert.Equal(raised.UserId, read.UserId);
        Assert.Equal(raised.Type, read.Type);
        Assert.Equal(raised.ReservationId, read.ReservationId);
        Assert.Equal(raised.Title, read.Title);
        Assert.Equal(raised.Body, read.Body);
        Assert.Equal(raised.CreatedAt, read.CreatedAt);
        Assert.Equal(DateTimeKind.Utc, read.CreatedAt.Kind);
    }

    // Raised beside the notification and read in the worker, so the pair the
    // client shows and the row it comes back to carry the same words.
    [Fact]
    public void APushSurvivesTheQueueAndCarriesTheNoticeItWasRaisedWith()
    {
        var raised = new NotificationMessage
        {
            UserId = 7,
            Type = NotificationType.ReservationCreated,
            ReservationId = 42,
            Title = "Your booking is held",
            Body = "The host has 24 hours to confirm it.",
            CreatedAt = new DateTime(2026, 6, 1, 12, 0, 0, DateTimeKind.Utc),
        };

        var read = RoundTrip(PushMessage.Of(raised));

        Assert.Equal(raised.UserId, read.UserId);
        Assert.Equal(raised.Type, read.Type);
        Assert.Equal(raised.ReservationId, read.ReservationId);
        Assert.Equal(raised.Title, read.Title);
        Assert.Equal(raised.Body, read.Body);
    }

    private static TMessage RoundTrip<TMessage>(TMessage message) =>
        JsonSerializer.Deserialize<TMessage>(
            JsonSerializer.SerializeToUtf8Bytes(message, MessageJson.Options),
            MessageJson.Options)!;
}
