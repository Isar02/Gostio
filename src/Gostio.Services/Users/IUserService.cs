using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Users;

public interface IUserService
    : ICrudService<UserResponse, UserSearchRequest, UserCreateRequest, UserUpdateRequest>
{
    Task<UserResponse> SetRolesAsync(
        int id,
        UserRolesRequest request,
        CancellationToken cancellationToken);

    Task<UserResponse> SetStateAsync(
        int id,
        UserStateRequest request,
        CancellationToken cancellationToken);
}
