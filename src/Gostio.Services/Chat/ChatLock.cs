using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Chat;

internal static class ChatLock
{
    // No index can state "these two people, once", because a thread's
    // membership is rows in another table, so two taps opening the same one at
    // the same moment otherwise both read that none exists and both write one.
    // The accounts are taken first and the second tap queues behind the first.
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
    // index holds them and two openings of the same pair cannot deadlock.
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
