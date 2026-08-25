using Microsoft.Data.SqlClient;

namespace Gostio.Services.Database;

internal static class DatabaseFailures
{
    private const int ForeignKeyViolation = 547;

    private const int UniqueIndexViolation = 2601;

    private const int UniqueConstraintViolation = 2627;

    public static bool IsStillReferenced(Exception failure) =>
        HasSqlErrorNumber(failure, ForeignKeyViolation);

    public static bool IsDuplicate(Exception failure) =>
        HasSqlErrorNumber(failure, UniqueIndexViolation, UniqueConstraintViolation);

    // Entity Framework wraps what the driver threw.
    private static bool HasSqlErrorNumber(Exception failure, params int[] numbers) =>
        (failure as SqlException ?? failure.InnerException as SqlException) is { } sql
        && numbers.Contains(sql.Number);
}
