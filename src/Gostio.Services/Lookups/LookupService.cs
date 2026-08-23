using System.Linq.Expressions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal abstract class LookupService<TEntity>(GostioDbContext db, string noun)
    : CrudService<TEntity, LookupResponse, LookupSearchRequest, LookupUpsertRequest, LookupUpsertRequest>(
        db,
        noun),
      ILookupService
    where TEntity : class, ILookupEntity, new()
{
    protected override Expression<Func<TEntity, LookupResponse>> Projection =>
        entity => new LookupResponse { Id = entity.Id, Name = entity.Name };

    protected override IOrderedQueryable<TEntity> Order(IQueryable<TEntity> query) =>
        query.OrderBy(entity => entity.Name).ThenBy(entity => entity.Id);

    protected override IQueryable<TEntity> Filter(
        IQueryable<TEntity> query,
        LookupSearchRequest search)
    {
        if (string.IsNullOrWhiteSpace(search.Name))
        {
            return query;
        }

        string term = search.Name.Trim();

        return query.Where(entity => entity.Name.Contains(term));
    }

    protected override async Task<TEntity> NewAsync(
        LookupUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var entity = new TEntity();

        await ApplyAsync(request, entity, cancellationToken);

        return entity;
    }

    protected override async Task ApplyAsync(
        LookupUpsertRequest request,
        TEntity entity,
        CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();

        await RequireUniqueAsync(
            candidate => candidate.Name == name,
            entity.Id,
            nameof(request.Name),
            $"Another {Noun} already goes by this name.",
            cancellationToken);

        entity.Name = name;
    }
}
