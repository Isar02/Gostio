using Gostio.Model.Exceptions;
using Microsoft.AspNetCore.Http;

namespace Gostio.Services.Authentication;

public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public int? UserId => accessor.HttpContext?.User.UserId();

    public int RequireUserId() =>
        UserId ?? throw new UnauthorizedException("This request needs a signed in user.");

    // The same claim [Authorize(Roles = ...)] reads, or the two would disagree.
    public bool IsInRole(string role) => accessor.HttpContext?.User.IsInRole(role) ?? false;
}
