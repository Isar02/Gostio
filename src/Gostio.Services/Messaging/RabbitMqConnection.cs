using System.Reflection;
using Gostio.Services.Configuration;
using RabbitMQ.Client;

namespace Gostio.Services.Messaging;

// One connection for the process, one publishing channel behind a gate: a
// channel is not safe to share, so a publish waits for the one in front of it.
public sealed class RabbitMqConnection(RabbitMqSettings settings) : IAsyncDisposable
{
    private static readonly TimeSpan RecoveryInterval = TimeSpan.FromSeconds(5);

    private readonly SemaphoreSlim gate = new(1, 1);

    private IConnection? connection;

    private IChannel? publishing;

    public async Task UseChannelAsync(
        Func<IChannel, Task> work,
        CancellationToken cancellationToken)
    {
        await gate.WaitAsync(cancellationToken);

        try
        {
            publishing = await ReadyAsync(publishing, Confirming, cancellationToken);

            await work(publishing);
        }
        finally
        {
            gate.Release();
        }
    }

    // A consumer holds its channel while it listens, so it owns this one.
    public async Task<IChannel> OpenChannelAsync(CancellationToken cancellationToken)
    {
        await gate.WaitAsync(cancellationToken);

        try
        {
            return await ReadyAsync(null, Plain, cancellationToken);
        }
        finally
        {
            gate.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        await DiscardAsync();

        gate.Dispose();
    }

    private static CreateChannelOptions Confirming => new(
        publisherConfirmationsEnabled: true,
        publisherConfirmationTrackingEnabled: true);

    private static CreateChannelOptions Plain => new(
        publisherConfirmationsEnabled: false,
        publisherConfirmationTrackingEnabled: false);

    private async Task<IChannel> ReadyAsync(
        IChannel? existing,
        CreateChannelOptions options,
        CancellationToken cancellationToken)
    {
        if (connection is { IsOpen: true } && existing is { IsOpen: true })
        {
            return existing;
        }

        if (connection is not { IsOpen: true })
        {
            await DiscardAsync();

            connection = await Factory().CreateConnectionAsync(cancellationToken);
        }

        var channel = await connection.CreateChannelAsync(options, cancellationToken);

        // Declared by whichever side connects first, so either may start first.
        foreach (var queue in MessageQueues.Declared(settings))
        {
            await channel.QueueDeclareAsync(
                queue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                cancellationToken: cancellationToken);
        }

        return channel;
    }

    private async Task DiscardAsync()
    {
        if (publishing is not null)
        {
            await publishing.DisposeAsync();

            publishing = null;
        }

        if (connection is not null)
        {
            await connection.DisposeAsync();

            connection = null;
        }
    }

    private ConnectionFactory Factory() => new()
    {
        HostName = settings.Host,
        Port = settings.Port,
        UserName = settings.Username,
        Password = settings.Password,
        VirtualHost = settings.VirtualHost,
        ClientProvidedName = Assembly.GetEntryAssembly()?.GetName().Name ?? "Gostio",
        AutomaticRecoveryEnabled = true,
        TopologyRecoveryEnabled = true,
        NetworkRecoveryInterval = RecoveryInterval,
    };
}
