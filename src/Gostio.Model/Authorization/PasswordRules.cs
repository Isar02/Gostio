namespace Gostio.Model.Authorization;

public static class PasswordRules
{
    public const int MinimumLength = 8;

    // bcrypt hashes the first 72 bytes and ignores the rest, so a password
    // longer than this is not the stronger one it looks like.
    public const int MaximumLength = 72;
}
