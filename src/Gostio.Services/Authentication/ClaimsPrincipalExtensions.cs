using System.Globalization;
using System.Security.Claims;
using Gostio.Model.Authorization;

namespace Gostio.Services.Authentication;

// Every reader of a token goes through here: the bearer events, the current
// user and the tests. A claim name spelled anywhere else is a claim name that
// can be spelled differently.
public static class ClaimsPrincipalExtensions
{
    public static int? UserId(this ClaimsPrincipal principal) =>
        Number(principal, GostioClaimTypes.UserId);

    public static int? TokenVersion(this ClaimsPrincipal principal) =>
        Number(principal, GostioClaimTypes.TokenVersion);

    public static string? Username(this ClaimsPrincipal principal) =>
        principal.FindFirst(GostioClaimTypes.Username)?.Value;

    public static IReadOnlyList<string> Roles(this ClaimsPrincipal principal) =>
        [.. principal.FindAll(GostioClaimTypes.Role).Select(claim => claim.Value)];

    private static int? Number(ClaimsPrincipal principal, string claimType) =>
        int.TryParse(
            principal.FindFirst(claimType)?.Value,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out var value)
            ? value
            : null;
}
