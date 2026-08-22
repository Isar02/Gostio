using Gostio.Model.Exceptions;
using Microsoft.AspNetCore.Http;

namespace Gostio.Services.Authentication;

public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public int? UserId => accessor.HttpContext?.User.UserId();

    public int RequireUserId() =>
        UserId ?? throw new UnauthorizedException("This request needs a signed in user.");
}
