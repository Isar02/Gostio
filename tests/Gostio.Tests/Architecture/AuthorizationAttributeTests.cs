using System.Reflection;
using Gostio.API.Middleware;
using Gostio.Model.Authorization;
using Microsoft.AspNetCore.Authorization;

namespace Gostio.Tests.Architecture;

// The attribute compares strings, so a role no seed writes is neither a build
// error nor a runtime one: it is an endpoint nobody can reach. Spelling the
// name as a constant is what makes that impossible, and this is what says so.
public class AuthorizationAttributeTests
{
    [Fact]
    public void EveryRoleAnAttributeNamesIsARoleTheSeedWrites()
    {
        var named = RolesNamedIn(typeof(ExceptionHandlingMiddleware).Assembly);

        // Not empty, or the check below would pass on an unread assembly.
        Assert.NotEmpty(named);
        Assert.Empty(named.Except(RoleNames.All));
    }

    private static IReadOnlyList<string> RolesNamedIn(Assembly assembly) =>
        [.. assembly.GetTypes()
            .SelectMany(Authorizations)
            .Select(attribute => attribute.Roles)
            .Where(roles => !string.IsNullOrWhiteSpace(roles))
            .SelectMany(roles => roles!.Split(
                ',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            .Distinct()
            .Order()];

    private static IEnumerable<AuthorizeAttribute> Authorizations(Type type) =>
        type.GetCustomAttributes<AuthorizeAttribute>()
            .Concat(type.GetMethods().SelectMany(method =>
                method.GetCustomAttributes<AuthorizeAttribute>()));
}
