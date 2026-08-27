using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Gostio.Services.Search;

internal sealed class SearchRecorder(
    GostioDbContext db,
    ICurrentUser currentUser,
    ILogger<SearchRecorder> logger)
    : ISearchRecorder
{
    private const int RecentSearchesConsidered = 10;

    public async Task RecordAsync(
        SearchSignal signal,
        DateTime searchedAt,
        CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not int userId || !SearchRules.NamesSomething(signal))
        {
            return;
        }

        // A search may name a city no row has, and the answer to that is an
        // empty page rather than an error. The signal behind it is dropped
        // instead of turning a search that answered into one that failed.
        try
        {
            await WriteAsync(userId, signal, searchedAt, cancellationToken);
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(failure, "A search over the {Target} was not recorded.", signal.Target);
        }
    }

    // A box that filters as it is typed has several requests of one search in
    // flight, so the account is taken first and the second queues behind it.
    // Which of them finishes last is settled by the moment each search started.
    private async Task WriteAsync(
        int userId,
        SearchSignal signal,
        DateTime searchedAt,
        CancellationToken cancellationToken)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await AccountLock.TakeAsync(db, userId, cancellationToken);

        var previous = await ContinuedAsync(userId, signal, searchedAt, cancellationToken);

        if (previous is null)
        {
            db.SearchHistory.Add(new SearchHistory
            {
                UserId = userId,
                Target = signal.Target,
                Term = signal.Term,
                CityId = signal.CityId,
                GuestCount = signal.GuestCount,
                MinPrice = signal.MinPrice,
                MaxPrice = signal.MaxPrice,
                SearchedAt = searchedAt,
            });

            await db.SaveChangesAsync(cancellationToken);
        }
        else if (searchedAt > previous.SearchedAt)
        {
            await db.SearchHistory
                .Where(row => row.Id == previous.Id)
                .ExecuteUpdateAsync(
                    row => row
                        .SetProperty(entry => entry.Term, signal.Term)
                        .SetProperty(entry => entry.SearchedAt, searchedAt),
                    cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    // Every row that can continue this search carries its filters exactly, so
    // the statement narrows on those and leaves `SearchRules` the term. The
    // newest row alone is not enough: a search in between would hide the prefix.
    private async Task<RecentSearch?> ContinuedAsync(
        int userId,
        SearchSignal signal,
        DateTime searchedAt,
        CancellationToken cancellationToken)
    {
        var since = searchedAt - SearchRules.SameSearchWindow;
        var until = searchedAt + SearchRules.SameSearchWindow;

        var candidates = await db.SearchHistory
            .AsNoTracking()
            .Where(row =>
                row.UserId == userId
                && row.Target == signal.Target
                && row.CityId == signal.CityId
                && row.GuestCount == signal.GuestCount
                && row.MinPrice == signal.MinPrice
                && row.MaxPrice == signal.MaxPrice
                && row.SearchedAt >= since
                && row.SearchedAt <= until)
            .OrderByDescending(row => row.SearchedAt)
            .ThenByDescending(row => row.Id)
            .Take(RecentSearchesConsidered)
            .Select(row => new RecentSearch(
                row.Id,
                new SearchSignal
                {
                    Target = row.Target,
                    Term = row.Term,
                    CityId = row.CityId,
                    GuestCount = row.GuestCount,
                    MinPrice = row.MinPrice,
                    MaxPrice = row.MaxPrice,
                },
                row.SearchedAt))
            .ToListAsync(cancellationToken);

        return candidates.FirstOrDefault(
            candidate => SearchRules.Continues(signal, candidate.Signal));
    }

    private sealed record RecentSearch(int Id, SearchSignal Signal, DateTime SearchedAt);
}
