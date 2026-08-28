using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

internal sealed class CommandCounter(string table) : DbCommandInterceptor
{
    private int reads;

    public int Reads => Volatile.Read(ref reads);

    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        if (command.CommandText.Contains($"[{table}]", StringComparison.Ordinal))
        {
            Interlocked.Increment(ref reads);
        }

        return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }
}
