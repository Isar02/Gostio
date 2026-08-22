using System.Security.Cryptography;
using System.Text;

namespace Gostio.Services.Authentication;

public static class ResetTokens
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromHours(24);

    private const int TokenBytes = 32;

    public static string Create() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(TokenBytes));

    // The row keeps this and never the token, so a copy of the database is not
    // a set of working links.
    public static string Hash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).ToLowerInvariant();
}
