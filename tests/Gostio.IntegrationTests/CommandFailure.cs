using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

// Fails the first command naming every fragment given. It is how a test puts a
// failure at one exact point of a call that has already written.
internal sealed class CommandFailure(params string[] required) : DbCommandInterceptor
{
    private int thrown;

    public bool Thrown => Volatile.Read(ref thrown) == 1;

    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        if (required.All(text => command.CommandText.Contains(text, StringComparison.Ordinal))
            && Interlocked.Exchange(ref thrown, 1) == 0)
        {
            throw new InvalidOperationException("This command was failed by the test.");
        }

        return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }
}
