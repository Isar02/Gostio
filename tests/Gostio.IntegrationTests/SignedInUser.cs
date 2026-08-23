using Gostio.Services.Authentication;

namespace Gostio.IntegrationTests;

internal sealed class SignedInUser(int userId, params string[] roles) : ICurrentUser
{
    public int? UserId => userId;

    public int RequireUserId() => userId;

    public bool IsInRole(string role) => roles.Contains(role);
}
