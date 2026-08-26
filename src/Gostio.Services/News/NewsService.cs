using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.News;

internal sealed class NewsService(GostioDbContext db, ICurrentUser currentUser) : INewsService
{
    private const string FileField = "File";

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

    public async Task<NewsResponse> WriteAsync(
        NewsUpsertRequest request,
        ImageUpload image,
        CancellationToken cancellationToken)
    {
        var contentType = ImageRules.RequireImage(image, FileField);

        var item = new NewsItem
        {
            CreatedByUserId = currentUser.RequireUserId(),
            Title = request.Title.Trim(),
            Body = request.Body.Trim(),
            Image = image.Content,
            ImageContentType = contentType,
            PublishedAt = DateTime.UtcNow,
        };

        db.News.Add(item);

        await db.SaveChangesAsync(cancellationToken);

        return await ReadAsync(item.Id, cancellationToken);
    }

    public async Task<NewsResponse> UpdateAsync(
        int id,
        NewsUpsertRequest request,
        ImageUpload? image,
        CancellationToken cancellationToken)
    {
        var title = request.Title.Trim();
        var body = request.Body.Trim();
        DateTime? modifiedAt = DateTime.UtcNow;

        (byte[] Content, string ContentType)? replacement = image is null
            ? null
            : (image.Content, ImageRules.RequireImage(image, FileField));

        // Column by column rather than through a tracked row: the image runs to
        // megabytes, and a corrected title has no reason to read it back.
        var updated = await db.News
            .Where(item => item.Id == id)
            .ExecuteUpdateAsync(
                setters =>
                {
                    setters.SetProperty(item => item.Title, title);
                    setters.SetProperty(item => item.Body, body);
                    setters.SetProperty(item => item.ModifiedAt, modifiedAt);

                    if (replacement is { } stored)
                    {
                        setters.SetProperty(item => item.Image, stored.Content);
                        setters.SetProperty(item => item.ImageContentType, stored.ContentType);
                    }
                },
                cancellationToken);

        if (updated == 0)
        {
            throw Missing(id);
        }

        return await ReadAsync(id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        var removed = await db.News
            .Where(item => item.Id == id)
            .ExecuteDeleteAsync(cancellationToken);

        if (removed == 0)
        {
            throw Missing(id);
        }
    }

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
