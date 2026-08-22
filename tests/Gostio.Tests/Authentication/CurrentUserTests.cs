using System.Security.Claims;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Microsoft.AspNetCore.Http;

namespace Gostio.Tests.Authentication;

public class CurrentUserTests
{
    [Fact]
    public void TheCallerIsReadFromTheTokenAndFromNowhereElse()
    {
        var current = new CurrentUser(Accessor(new Claim(GostioClaimTypes.UserId, "42")));

        Assert.Equal(42, current.UserId);
        Assert.Equal(42, current.RequireUserId());
    }

    [Fact]
    public void ARequestWithoutATokenHasNoCaller()
    {
        var current = new CurrentUser(Accessor());

        Assert.Null(current.UserId);
        Assert.Throws<UnauthorizedException>(() => current.RequireUserId());
    }

    // The worker resolves the same services with no request in flight.
    [Fact]
    public void ACallOutsideARequestHasNoCaller()
    {
        var current = new CurrentUser(new StubAccessor(null));

        Assert.Null(current.UserId);
        Assert.Throws<UnauthorizedException>(() => current.RequireUserId());
    }

    private static IHttpContextAccessor Accessor(params Claim[] claims) =>
        new StubAccessor(new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(claims, "Test")),
        });

    private sealed class StubAccessor(HttpContext? context) : IHttpContextAccessor
    {
        public HttpContext? HttpContext { get; set; } = context;
    }
}
