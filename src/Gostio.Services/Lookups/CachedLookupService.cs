using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Lookups;

internal abstract class CachedLookupService<TEntity, TResponse, TSearch, TCreate, TUpdate>(
    GostioDbContext db,
    string noun,
    ILookupCache cache)
    : CrudService<TEntity, TResponse, TSearch, TCreate, TUpdate>(db, noun)
    where TEntity : class, IEntity
    where TResponse : class
    where TSearch : PagedRequest
{
    // Filter is what says whether the whole table was asked for: a filter that
    // is set composes a new query, so a query that came back untouched is the
    // table itself.
    public override async Task<PagedResult<TResponse>> SearchAsync(
        TSearch search,
        CancellationToken cancellationToken)
    {
        var all = Set.AsNoTracking();

        if (!ReferenceEquals(Filter(all, search), all))
        {
            return await base.SearchAsync(search, cancellationToken);
        }

        var rows = await cache.ReadAsync(
            typeof(TEntity),
            token => Order(all).Select(Projection).ToListAsync(token),
            cancellationToken);

        return rows.ToPagedResult(search);
    }

    // All three evict in a finally: the create and the update read the row
    // back after saving it, and a readback that fails would otherwise leave
    // the change committed and the old list held. Evicting after a write that
    // never happened costs one query.
    public override async Task<TResponse> CreateAsync(
        TCreate request,
        CancellationToken cancellationToken)
    {
        try
        {
            return await base.CreateAsync(request, cancellationToken);
        }
        finally
        {
            cache.Evict(typeof(TEntity));
        }
    }

    public override async Task<TResponse> UpdateAsync(
        int id,
        TUpdate request,
        CancellationToken cancellationToken)
    {
        try
        {
            return await base.UpdateAsync(id, request, cancellationToken);
        }
        finally
        {
            cache.Evict(typeof(TEntity));
        }
    }

    public override async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        try
        {
            await base.DeleteAsync(id, cancellationToken);
        }
        finally
        {
            cache.Evict(typeof(TEntity));
        }
    }
}
