using System.Linq.Expressions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Database;

public static class PagingExtensions
{
    // IOrderedQueryable rather than IQueryable: skipping over an unordered
    // query lets the database return rows in any order it likes, so page two
    // can repeat page one. The projection runs inside the page, so a list never
    // drags the image columns an entity holds.
    public static async Task<PagedResult<TResult>> ToPagedResultAsync<TSource, TResult>(
        this IOrderedQueryable<TSource> source,
        PagedRequest request,
        Expression<Func<TSource, TResult>> selector,
        CancellationToken cancellationToken)
    {
        var totalCount = await source.CountAsync(cancellationToken);

        // A page beginning past the last row has nothing to fetch, and its
        // offset need not even fit in the int that Skip takes.
        List<TResult> items = request.Offset >= totalCount
            ? []
            : await source
                .Skip((int)request.Offset)
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

    public static PagedResult<T> ToPagedResult<T>(
        this IReadOnlyList<T> source,
        PagedRequest request)
    {
        List<T> items = request.Offset >= source.Count
            ? []
            : [.. source.Skip((int)request.Offset).Take(request.PageSize)];

        return new PagedResult<T>
        {
            Items = items,
            Page = request.Page,
            PageSize = request.PageSize,
            TotalCount = source.Count,
        };
    }
}
