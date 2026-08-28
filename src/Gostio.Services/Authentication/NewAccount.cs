using Gostio.Model.Requests;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Authentication;

internal sealed class NewAccount(AccountCreateRequest request)
{
    public string Username { get; } = request.Username.Trim();

    public string Email { get; } = request.Email.Trim();

    public User CreateUser(IReadOnlyList<int> roleIds, DateTime now) => new()
    {
        FirstName = request.FirstName.Trim(),
        LastName = request.LastName.Trim(),
        Username = Username,
        Email = Email,
        PhoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber)
            ? null
            : request.PhoneNumber.Trim(),
        PasswordHash = PasswordHasher.Hash(request.Password),
        CreatedAt = now,
        UserRoles =
            [.. roleIds.Select(roleId => new UserRole { RoleId = roleId, AssignedAt = now })],
    };
}
