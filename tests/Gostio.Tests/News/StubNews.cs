using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.News;

namespace Gostio.Tests.News;

internal sealed class StubNews : INewsService
{
    public static byte[] Bytes => [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

    public NewsSearchRequest? LastSearch { get; private set; }

    public Task<PagedResult<NewsResponse>> SearchAsync(
        NewsSearchRequest search,
        CancellationToken cancellationToken)
    {
        LastSearch = search;

        return Task.FromResult(new PagedResult<NewsResponse>
        {
            Items = [Row(1)],
            Page = search.Page,
            PageSize = search.PageSize,
            TotalCount = 1,
        });
    }

    public Task<NewsResponse> GetAsync(int id, CancellationToken cancellationToken) =>
        Task.FromResult(Row(id));

    public Task<ImageContent> GetImageAsync(int id, CancellationToken cancellationToken) =>
        Task.FromResult(new ImageContent(Bytes, ImageRules.Jpeg));

    private static NewsResponse Row(int id) => new()
    {
        Id = id,
        Title = "A title",
        Body = "The text under it.",
        ImageContentType = ImageRules.Jpeg,
        AuthorId = 42,
        AuthorName = "An Administrator",
        PublishedAt = new DateTime(2026, 8, 26, 9, 0, 0, DateTimeKind.Utc),
    };
}
