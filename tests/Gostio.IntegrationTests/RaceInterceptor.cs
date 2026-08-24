using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

// Runs one change just before a matching command is sent. It is how a test makes
// the world move underneath a call that is already on its way, without waiting
// for a window it cannot see. `after` names which of the matches to move in
// front of, for a gap that opens between two commands rather than before the
// first.
internal sealed class RaceInterceptor(string required, Func<Task> change, int after = 0)
    : DbCommandInterceptor
{
    private int seen = -1;

    private int fired;

    public bool Fired => Volatile.Read(ref fired) == 1;

    public override async ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        await RunTheChangeAsync(command);

        return result;
    }

    public override async ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        await RunTheChangeAsync(command);

        return result;
    }

    private async Task RunTheChangeAsync(DbCommand command)
    {
        if (command.CommandText.Contains(required, StringComparison.Ordinal)
            && Interlocked.Increment(ref seen) == after)
        {
            Volatile.Write(ref fired, 1);

            await change();
        }
    }
}
