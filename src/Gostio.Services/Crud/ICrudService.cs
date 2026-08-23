using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Crud;

public interface ICrudService<TResponse, TSearch, TCreate, TUpdate>
    where TSearch : PagedRequest
{
    Task<PagedResult<TResponse>> SearchAsync(TSearch search, CancellationToken cancellationToken);

    Task<TResponse> GetAsync(int id, CancellationToken cancellationToken);

    Task<TResponse> CreateAsync(TCreate request, CancellationToken cancellationToken);

    Task<TResponse> UpdateAsync(int id, TUpdate request, CancellationToken cancellationToken);

    Task DeleteAsync(int id, CancellationToken cancellationToken);
}
