using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Crud;

internal abstract class CrudService<TEntity, TResponse, TSearch, TCreate, TUpdate>(
    GostioDbContext db,
    string noun)
    : ICrudService<TResponse, TSearch, TCreate, TUpdate>
    where TEntity : class, IEntity
    where TResponse : class
    where TSearch : PagedRequest
{
    protected GostioDbContext Db { get; } = db;

    protected string Noun { get; } = noun;

    protected DbSet<TEntity> Set => Db.Set<TEntity>();

    protected virtual string StillReferencedMessage =>
        $"This {Noun} is used by other records and cannot be deleted.";

    protected abstract Expression<Func<TEntity, TResponse>> Projection { get; }

    public virtual Task<PagedResult<TResponse>> SearchAsync(
        TSearch search,
        CancellationToken cancellationToken) =>
        Order(Filter(Set.AsNoTracking(), search))
            .ToPagedResultAsync(search, Projection, cancellationToken);

    public virtual Task<TResponse> GetAsync(int id, CancellationToken cancellationToken) =>
        ReadAsync(id, cancellationToken);

    public virtual async Task<TResponse> CreateAsync(
        TCreate request,
        CancellationToken cancellationToken)
    {
        var entity = await NewAsync(request, cancellationToken);

        Set.Add(entity);

        await Db.SaveChangesAsync(cancellationToken);

        return await ReadAsync(entity.Id, cancellationToken);
    }

    public virtual async Task<TResponse> UpdateAsync(
        int id,
        TUpdate request,
        CancellationToken cancellationToken)
    {
        var entity = await RequireAsync(id, cancellationToken);

        await ApplyAsync(request, entity, cancellationToken);

        await Db.SaveChangesAsync(cancellationToken);

        return await ReadAsync(id, cancellationToken);
    }

    // One statement, not a load and a Remove: the change tracker severs what it
    // already holds and breaks the delete before the database sees it.
    public virtual async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        int removed;

        try
        {
            removed = await Set
                .Where(entity => entity.Id == id)
                .ExecuteDeleteAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsStillReferenced(failure))
        {
            throw new BusinessException(StillReferencedMessage);
        }

        if (removed == 0)
        {
            throw Missing(id);
        }
    }

    protected abstract IOrderedQueryable<TEntity> Order(IQueryable<TEntity> query);

    protected abstract Task<TEntity> NewAsync(TCreate request, CancellationToken cancellationToken);

    protected abstract Task ApplyAsync(
        TUpdate request,
        TEntity entity,
        CancellationToken cancellationToken);

    protected virtual IQueryable<TEntity> Filter(IQueryable<TEntity> query, TSearch search) => query;

    // A row being created has no id yet, so passing its own excludes nothing
    // and one method serves both writes.
    protected async Task RequireUniqueAsync(
        Expression<Func<TEntity, bool>> duplicate,
        int excludeId,
        string field,
        string message,
        CancellationToken cancellationToken)
    {
        var taken = await Set
            .AsNoTracking()
            .Where(duplicate)
            .AnyAsync(entity => entity.Id != excludeId, cancellationToken);

        if (taken)
        {
            throw new ValidationException(field, message);
        }
    }

    protected async Task<TResponse> ReadAsync(int id, CancellationToken cancellationToken) =>
        await Set
            .AsNoTracking()
            .Where(entity => entity.Id == id)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    protected async Task<TEntity> RequireAsync(int id, CancellationToken cancellationToken) =>
        await Set.FirstOrDefaultAsync(entity => entity.Id == id, cancellationToken)
        ?? throw Missing(id);

    protected static string? Trimmed(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    protected NotFoundException Missing(int id) => new($"No {Noun} has the id {id}.");
}
