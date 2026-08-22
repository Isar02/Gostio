using System.Linq.Expressions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Database;

public static class QueryablePagingExtensions
{
    // The caller orders the query: without an ORDER BY the database may return
    // rows in any order, so page two can repeat page one. The projection runs
    // inside the page, so a list never drags the image columns an entity holds.
    public static async Task<PagedResult<TResult>> ToPagedResultAsync<TSource, TResult>(
        this IQueryable<TSource> source,
        PagedRequest request,
        Expression<Func<TSource, TResult>> selector,
        CancellationToken cancellationToken)
    {
        var totalCount = await source.CountAsync(cancellationToken);

        var items = await source
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(selector)
            .ToListAsync(cancellationToken);

        return new PagedResult<TResult>
        {
            Items = items,
            Page = request.Page,
            PageSize = request.PageSize,
            TotalCount = totalCount,
        };
    }
}
