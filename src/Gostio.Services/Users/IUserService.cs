using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Users;

public interface IUserService
    : ICrudService<UserResponse, UserSearchRequest, UserCreateRequest, UserUpdateRequest>
{
    Task<UserResponse> GetMineAsync(CancellationToken cancellationToken);

    Task<UserResponse> UpdateMineAsync(
        UserUpdateRequest request,
        CancellationToken cancellationToken);

    Task<ImageContent> GetImageAsync(int id, CancellationToken cancellationToken);

    Task<UserResponse> SetImageAsync(
        int id,
        ImageUpload upload,
        CancellationToken cancellationToken);

    Task<UserResponse> SetMineImageAsync(
        ImageUpload upload,
        CancellationToken cancellationToken);

    Task ClearImageAsync(int id, CancellationToken cancellationToken);

    Task ClearMineImageAsync(CancellationToken cancellationToken);

    Task<UserResponse> SetRolesAsync(
        int id,
        UserRolesRequest request,
        CancellationToken cancellationToken);

    Task<UserResponse> SetStateAsync(
        int id,
        UserStateRequest request,
        CancellationToken cancellationToken);

    Task SetPasswordAsync(
        int id,
        NewPasswordRequest request,
        CancellationToken cancellationToken);
}
