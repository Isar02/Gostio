using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Crud;

// The shape every managed table shares: a filtered page that projects, a read
// by id, and writes that answer with the row as it now stands rather than with
// what the request said. Subclasses supply the projection, the ordering, the
// filters and the two methods that turn a request into columns.
internal abstract class CrudService<TEntity, TResponse, TSearch, TCreate, TUpdate>(
    GostioDbContext db,
    string noun)
    : ICrudService<TResponse, TSearch, TCreate, TUpdate>
    where TEntity : class, IEntity
    where TResponse : class
    where TSearch : PagedRequest
{
    private const int ForeignKeyViolation = 547;

    protected GostioDbContext Db { get; } = db;

    // Named once so every message about the table reads the same way.
    protected string Noun { get; } = noun;

    protected DbSet<TEntity> Set => Db.Set<TEntity>();

    // Refused rather than cascaded: a reference table row that something points
    // at is removed by removing what points at it first.
    protected virtual string StillReferencedMessage =>
        $"This {Noun} is used by other records and cannot be deleted.";

    protected abstract Expression<Func<TEntity, TResponse>> Projection { get; }

    public Task<PagedResult<TResponse>> SearchAsync(
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

    // One statement rather than a load and a Remove: the change tracker severs
    // the relationships of anything it already holds, so a row read earlier in
    // the same request would break the delete before the database saw it.
    public virtual async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        int removed;

        try
        {
            removed = await Set
                .Where(entity => entity.Id == id)
                .ExecuteDeleteAsync(cancellationToken);
        }
        catch (Exception failure) when (IsStillReferenced(failure))
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

    private static bool IsStillReferenced(Exception failure) =>
        failure is SqlException { Number: ForeignKeyViolation }
        || failure.InnerException is SqlException { Number: ForeignKeyViolation };

    private NotFoundException Missing(int id) => new($"No {Noun} has the id {id}.");
}
