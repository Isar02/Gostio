using Gostio.Services.Authentication;

namespace Gostio.IntegrationTests;

internal sealed class SignedInUser(int userId) : ICurrentUser
{
    public int? UserId => userId;

    public int RequireUserId() => userId;
}
