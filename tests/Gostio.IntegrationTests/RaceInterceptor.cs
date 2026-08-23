using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

// Runs one change just before the first command matching the text is sent. It
// is how a test makes the world move underneath a read that is already on its
// way, without waiting for a window it cannot see.
internal sealed class RaceInterceptor(string required, Func<Task> change) : DbCommandInterceptor
{
    private int fired;

    public bool Fired => Volatile.Read(ref fired) == 1;

    public override async ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        if (command.CommandText.Contains(required, StringComparison.Ordinal)
            && Interlocked.Exchange(ref fired, 1) == 0)
        {
            await change();
        }

        return result;
    }
}
