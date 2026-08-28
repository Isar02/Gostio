using System.Collections.Concurrent;
using Gostio.Services.Configuration;
using Gostio.Services.Database.Entities;
using Microsoft.Extensions.Caching.Memory;

namespace Gostio.Services.Lookups;

internal sealed class LookupCache(IMemoryCache cache, CacheSettings settings) : ILookupCache
{
    // A cached row carrying a column of another table has to be dropped when
    // that table is written and not only when its own is: a city answers with
    // its country's name, so a renamed country otherwise leaves every city
    // reporting the old one.
    private static readonly Dictionary<Type, Type[]> Dependants =
        new() { [typeof(Country)] = [typeof(City)] };

    private readonly ConcurrentDictionary<Type, TableState> tables = new();

    public async Task<IReadOnlyList<T>> ReadAsync<T>(
        Type table,
        Func<CancellationToken, Task<List<T>>> load,
        CancellationToken cancellationToken)
    {
        var state = StateOf(table);

        if (Held(table, state, out IReadOnlyList<T>? held))
        {
            return held;
        }

        await state.Gate.WaitAsync(cancellationToken);

        try
        {
            if (Held(table, state, out held))
            {
                return held;
            }

            var generation = state.Generation;
            var rows = await load(cancellationToken);

            // The generation these rows were read under is stored with them
            // rather than compared before storing them. A write can land at any
            // point up to and including this line, and an entry it superseded
            // is one every reader after it treats as a miss. Testing first
            // would leave a write the gap between the test and the store.
            cache.Set(
                new Key(table),
                new Entry<T>(generation, rows),
                settings.LookupLifetime);

            return rows;
        }
        finally
        {
            state.Gate.Release();
        }
    }

    public void Evict(Type table)
    {
        Drop(table);

        foreach (var dependant in Dependants.GetValueOrDefault(table, []))
        {
            Drop(dependant);
        }
    }

    private void Drop(Type table)
    {
        StateOf(table).Moved();

        cache.Remove(new Key(table));
    }

    private bool Held<T>(Type table, TableState state, out IReadOnlyList<T> rows)
    {
        if (cache.TryGetValue(new Key(table), out Entry<T>? entry)
            && entry is not null
            && entry.Generation == state.Generation)
        {
            rows = entry.Rows;

            return true;
        }

        rows = [];

        return false;
    }

    private TableState StateOf(Type table) => tables.GetOrAdd(table, _ => new TableState());

    private readonly record struct Key(Type Table);

    private sealed record Entry<T>(long Generation, IReadOnlyList<T> Rows);

    private sealed class TableState
    {
        private long generation;

        public SemaphoreSlim Gate { get; } = new(1, 1);

        public long Generation => Interlocked.Read(ref generation);

        public void Moved() => Interlocked.Increment(ref generation);
    }
}
