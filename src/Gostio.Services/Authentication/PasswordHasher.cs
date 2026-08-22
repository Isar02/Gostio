namespace Gostio.Services.Authentication;

public static class PasswordHasher
{
    private const int WorkFactor = 11;

    // Made once from a random string that was never written down, so no
    // password verifies against it and every attempt costs a full hash.
    private const string UnmatchableHash =
        "$2a$11$xMaU7rD054lhT.eJ0UriEON4skxMqU/n58c1UasCVHZ.rzBDnTMfC";

    public static string Hash(string password) =>
        BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);

    public static bool Verify(string password, string hash) =>
        BCrypt.Net.BCrypt.Verify(password, hash);

    public static bool VerifyAgainstNothing(string password) =>
        BCrypt.Net.BCrypt.Verify(password, UnmatchableHash);
}
