using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Database;

internal static class AccountLock
{
    // Writers on one account queue here: under read committed snapshot two of
    // them otherwise read the same rows and both write what neither found.
    public static Task TakeAsync(
        GostioDbContext db,
        int userId,
        CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlAsync(
            $"""
            SELECT [Id] FROM [Users] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {userId}
            """,
            cancellationToken);

    // One statement rather than two, so the rows are taken in the order the
    // index holds them and two callers naming the same pair cannot deadlock.
    public static Task TakeAsync(
        GostioDbContext db,
        int userId,
        int otherUserId,
        CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlAsync(
            $"""
            SELECT [Id] FROM [Users] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Id] IN ({userId}, {otherUserId})
            """,
            cancellationToken);
}
