using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.HostVerification;

public interface IHostVerificationService
{
    Task<PagedResult<HostVerificationRequestResponse>> SearchAsync(
        HostVerificationSearchRequest search,
        CancellationToken cancellationToken);

    Task<HostVerificationRequestResponse> GetAsync(int id, CancellationToken cancellationToken);

    Task<HostVerificationRequestResponse> ApplyAsync(CancellationToken cancellationToken);
}
