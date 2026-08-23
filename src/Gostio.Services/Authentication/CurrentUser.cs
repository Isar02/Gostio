using Gostio.Model.Exceptions;
using Microsoft.AspNetCore.Http;

namespace Gostio.Services.Authentication;

public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public int? UserId => accessor.HttpContext?.User.UserId();

    public int RequireUserId() =>
        UserId ?? throw new UnauthorizedException("This request needs a signed in user.");

    // Read from the token like everything else here. The bearer options name
    // the role claim, so this asks the same claim the attribute does.
    public bool IsInRole(string role) => accessor.HttpContext?.User.IsInRole(role) ?? false;
}
