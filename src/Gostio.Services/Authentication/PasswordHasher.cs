namespace Gostio.Services.Authentication;

// The seed and the login path have to agree on the algorithm and the work
// factor, or a seeded account cannot sign in. One place decides both.
public static class PasswordHasher
{
    // Stated rather than left to the library default, which a new version of
    // the package is free to change underneath hashes already stored.
    private const int WorkFactor = 11;

    public static string Hash(string password) =>
        BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);

    public static bool Verify(string password, string hash) =>
        BCrypt.Net.BCrypt.Verify(password, hash);
}
