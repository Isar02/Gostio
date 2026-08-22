using System.Reflection;
using Gostio.API.Middleware;
using Gostio.Model.Authorization;
using Gostio.Tests.Authentication;
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

        Assert.Empty(named.Except(RoleNames.All));
    }

    // The API names no role yet, so the check above would pass on an empty list
    // whether it read the attributes or not. This one reads an assembly that
    // does name one.
    [Fact]
    public void TheAttributesAreActuallyRead()
    {
        var named = RolesNamedIn(typeof(SecuredProbeController).Assembly);

        Assert.Contains(RoleNames.Administrator, named);
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
