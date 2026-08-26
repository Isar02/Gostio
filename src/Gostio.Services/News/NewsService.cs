using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.News;

internal sealed class NewsService(GostioDbContext db) : INewsService
{
    private static Expression<Func<NewsItem, NewsResponse>> Projection =>
        item => new NewsResponse
        {
            Id = item.Id,
            Title = item.Title,
            Body = item.Body,
            ImageContentType = item.ImageContentType,
            AuthorId = item.CreatedByUserId,
            AuthorName = item.CreatedByUser.FirstName + " " + item.CreatedByUser.LastName,
            PublishedAt = item.PublishedAt,
            ModifiedAt = item.ModifiedAt,
        };

    public Task<PagedResult<NewsResponse>> SearchAsync(
        NewsSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(db.News.AsNoTracking(), search)
            .OrderByDescending(item => item.PublishedAt)
            .ThenByDescending(item => item.Id)
            .ToPagedResultAsync(search, Projection, cancellationToken);

    public Task<NewsResponse> GetAsync(int id, CancellationToken cancellationToken) =>
        ReadAsync(id, cancellationToken);

    public async Task<ImageContent> GetImageAsync(int id, CancellationToken cancellationToken) =>
        await db.News
            .AsNoTracking()
            .Where(item => item.Id == id)
            .Select(item => new ImageContent(item.Image, item.ImageContentType))
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    private static IQueryable<NewsItem> Matching(
        IQueryable<NewsItem> query,
        NewsSearchRequest search)
    {
        if (!string.IsNullOrWhiteSpace(search.Title))
        {
            var title = search.Title.Trim();

            query = query.Where(item => item.Title.Contains(title));
        }

        if (search.PublishedFrom is DateTime from)
        {
            query = query.Where(item => item.PublishedAt >= from);
        }

        if (search.PublishedTo is DateTime until)
        {
            query = query.Where(item => item.PublishedAt <= until);
        }

        return query;
    }

    private async Task<NewsResponse> ReadAsync(int id, CancellationToken cancellationToken) =>
        await db.News
            .AsNoTracking()
            .Where(item => item.Id == id)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    private static NotFoundException Missing(int id) => new($"No news has the id {id}.");
}
