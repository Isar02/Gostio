namespace Gostio.Services.Lookups;

public interface ILookupCache
{
    Task<IReadOnlyList<T>> ReadAsync<T>(
        Type table,
        Func<CancellationToken, Task<List<T>>> load,
        CancellationToken cancellationToken);

    void Evict(Type table);
}
