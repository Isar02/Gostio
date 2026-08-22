using System.Globalization;
using System.Security.Claims;
using Gostio.Model.Authorization;

namespace Gostio.Services.Authentication;

public static class ClaimsPrincipalExtensions
{
    public static int? UserId(this ClaimsPrincipal principal) =>
        Number(principal, GostioClaimTypes.UserId);

    public static int? TokenVersion(this ClaimsPrincipal principal) =>
        Number(principal, GostioClaimTypes.TokenVersion);

    private static int? Number(ClaimsPrincipal principal, string claimType) =>
        int.TryParse(
            principal.FindFirst(claimType)?.Value,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out var value)
            ? value
            : null;
}
