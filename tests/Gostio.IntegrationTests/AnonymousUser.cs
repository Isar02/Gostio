using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;

namespace Gostio.IntegrationTests;

// What the reset endpoints run as. Asking it who is calling throws, which is
// the assertion that they never do.
internal sealed class AnonymousUser : ICurrentUser
{
    public int? UserId => null;

    public int RequireUserId() =>
        throw new UnauthorizedException("This request needs a signed in user.");

    public bool IsInRole(string role) => false;
}
