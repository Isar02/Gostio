using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Services.Messaging;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Messaging;

// The notification row is the record and the push is a delivery of it. A push
// the row never backs is a notice the guest cannot come back to, so the order
// between the two is one way round only.
public class NoticePairingTests
{
    [Fact]
    public async Task ARowThatReachedTheBrokerTakesThePushWithIt()
    {
        var broker = new CountingPublisher();

        await using var provider = Messaging(broker);

        await provider.GetRequiredService<INotices>().NotifyAsync(ANotice(), default);

        Assert.Equal([typeof(NotificationMessage), typeof(PushMessage)], broker.Attempted);
    }

    // The publisher swallows what it could not send, so this is exactly the
    // case a caller cannot see for itself.
    [Fact]
    public async Task ARowTheBrokerRefusedTakesNoPushWithIt()
    {
        var broker = new CountingPublisher { Refuses = typeof(NotificationMessage) };

        await using var provider = Messaging(broker);

        await provider.GetRequiredService<INotices>().NotifyAsync(ANotice(), default);

        Assert.Equal([typeof(NotificationMessage)], broker.Attempted);
    }

    [Fact]
    public async Task APushTheBrokerRefusedIsStillNotHandedBack()
    {
        var broker = new CountingPublisher { Refuses = typeof(PushMessage) };

        await using var provider = Messaging(broker);

        await provider.GetRequiredService<INotices>().NotifyAsync(ANotice(), default);

        Assert.Equal([typeof(NotificationMessage), typeof(PushMessage)], broker.Attempted);
    }

    private static ServiceProvider Messaging(IMessagePublisher broker)
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddGostioMessaging();
        services.AddSingleton(broker);

        return services.BuildServiceProvider();
    }

    private static NotificationMessage ANotice() => new()
    {
        UserId = 7,
        Type = NotificationType.ReservationCreated,
        ReservationId = 42,
        Title = "Your booking is held",
        Body = "The host has 24 hours to confirm it.",
        CreatedAt = new DateTime(2026, 6, 1, 12, 0, 0, DateTimeKind.Utc),
    };

    private sealed class CountingPublisher : IMessagePublisher
    {
        private readonly List<Type> attempted = [];

        public IReadOnlyList<Type> Attempted => attempted;

        public Type? Refuses { get; init; }

        public Task PublishAsync<TMessage>(TMessage message, CancellationToken cancellationToken)
            where TMessage : class
        {
            attempted.Add(typeof(TMessage));

            return typeof(TMessage) == Refuses
                ? throw new InvalidOperationException("The broker refused the publish.")
                : Task.CompletedTask;
        }
    }
}
