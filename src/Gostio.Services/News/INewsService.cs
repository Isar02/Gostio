using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.News;

public interface INewsService
{
    Task<PagedResult<NewsResponse>> SearchAsync(
        NewsSearchRequest search,
        CancellationToken cancellationToken);

    Task<NewsResponse> GetAsync(int id, CancellationToken cancellationToken);

    Task<ImageContent> GetImageAsync(int id, CancellationToken cancellationToken);

    Task<NewsResponse> WriteAsync(
        NewsUpsertRequest request,
        ImageUpload image,
        CancellationToken cancellationToken);

    Task<NewsResponse> UpdateAsync(
        int id,
        NewsUpsertRequest request,
        ImageUpload? image,
        CancellationToken cancellationToken);

    Task DeleteAsync(int id, CancellationToken cancellationToken);
}
