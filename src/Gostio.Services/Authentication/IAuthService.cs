using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Authentication;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken);

    Task<UserResponse> GetCurrentUserAsync(CancellationToken cancellationToken);

    Task<AuthResponse> ChangePasswordAsync(
        ChangePasswordRequest request,
        CancellationToken cancellationToken);

    Task LogoutAsync(CancellationToken cancellationToken);
}
