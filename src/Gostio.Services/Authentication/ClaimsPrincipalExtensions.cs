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

    // A socket outlives the moment its token was validated, so what the token
    // said about its own life has to be kept and asked again.
    public static DateTimeOffset? ExpiresAt(this ClaimsPrincipal principal) =>
        long.TryParse(
            principal.FindFirst("exp")?.Value,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out var seconds)
            ? DateTimeOffset.FromUnixTimeSeconds(seconds)
            : null;

    private static int? Number(ClaimsPrincipal principal, string claimType) =>
        int.TryParse(
            principal.FindFirst(claimType)?.Value,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out var value)
            ? value
            : null;
}
