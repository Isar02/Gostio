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

    // Read from the same claim [Authorize(Roles = ...)] compares, or the check
    // in the service and the check on the endpoint would disagree.
    [Fact]
    public void TheRolesAreReadFromTheSameClaimTheAttributeReads()
    {
        var current = new CurrentUser(Accessor(
            new Claim(GostioClaimTypes.UserId, "42"),
            new Claim(GostioClaimTypes.Role, RoleNames.Administrator)));

        Assert.True(current.IsInRole(RoleNames.Administrator));
        Assert.False(current.IsInRole(RoleNames.Guest));
    }

    [Fact]
    public void ARequestWithoutATokenIsInNoRole()
    {
        Assert.False(new CurrentUser(Accessor()).IsInRole(RoleNames.Administrator));
    }

    // The worker resolves the same services with no request in flight.
    [Fact]
    public void ACallOutsideARequestHasNoCaller()
    {
        var current = new CurrentUser(new StubAccessor(null));

        Assert.Null(current.UserId);
        Assert.Throws<UnauthorizedException>(() => current.RequireUserId());
    }

    // The role claim type is named, because ClaimsPrincipal.IsInRole reads the
    // one the identity was built with rather than the one the token carries.
    private static IHttpContextAccessor Accessor(params Claim[] claims) =>
        new StubAccessor(new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                claims, "Test", GostioClaimTypes.Username, GostioClaimTypes.Role)),
        });

    private sealed class StubAccessor(HttpContext? context) : IHttpContextAccessor
    {
        public HttpContext? HttpContext { get; set; } = context;
    }
}
