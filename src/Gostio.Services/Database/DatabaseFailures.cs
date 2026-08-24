using Microsoft.Data.SqlClient;

namespace Gostio.Services.Database;

internal static class DatabaseFailures
{
    private const int ForeignKeyViolation = 547;

    public static bool IsStillReferenced(Exception failure) =>
        failure is SqlException { Number: ForeignKeyViolation }
        || failure.InnerException is SqlException { Number: ForeignKeyViolation };
}
