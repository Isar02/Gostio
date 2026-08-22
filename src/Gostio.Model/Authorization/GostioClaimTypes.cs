namespace Gostio.Model.Authorization;

// The names a token carries. Inbound claim mapping is turned off, so what is
// written here is what the server reads back rather than the WS-Federation URIs
// ASP.NET substitutes by default.
public static class GostioClaimTypes
{
    public const string UserId = "sub";

    public const string Username = "username";

    public const string Email = "email";

    public const string Role = "role";

    // Compared against the user row on every request, so signing out or
    // deactivating an account takes effect before the token expires.
    public const string TokenVersion = "token_version";
}
