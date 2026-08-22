using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

// Holds every command that matches until as many of them are waiting as the
// test says there are callers, then lets them all go at once. It holds them
// before the statement is sent, so nothing is waiting on a lock while it does.
internal sealed class CommandBarrier(int callers, params string[] required) : DbCommandInterceptor
{
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(15);

    private readonly TaskCompletionSource released =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    private int arrived;

    public int Arrived => Volatile.Read(ref arrived);

    public override async ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        await WaitForTheOthersAsync(command, cancellationToken);

        return result;
    }

    public override async ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        await WaitForTheOthersAsync(command, cancellationToken);

        return result;
    }

    private async Task WaitForTheOthersAsync(DbCommand command, CancellationToken cancellationToken)
    {
        if (!required.All(text => command.CommandText.Contains(text, StringComparison.Ordinal)))
        {
            return;
        }

        if (Interlocked.Increment(ref arrived) >= callers)
        {
            released.TrySetResult();
            return;
        }

        try
        {
            await released.Task.WaitAsync(Patience, cancellationToken);
        }
        catch (TimeoutException)
        {
            throw new TimeoutException(
                $"Only {Arrived} of {callers} callers reached a command matching "
                    + $"[{string.Join(", ", required)}] within {Patience.TotalSeconds} seconds.");
        }
    }
}
