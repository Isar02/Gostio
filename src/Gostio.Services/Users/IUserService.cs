using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Users;

// Roles and activation are not part of the update, because who may change them
// is not who may change the rest: an account holder edits their own profile,
// and only an administrator decides what that account may do.
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
