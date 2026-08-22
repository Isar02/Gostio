namespace Gostio.Model.Authorization;

public static class PasswordRules
{
    public const int MinimumLength = 8;

    // bcrypt hashes the first 72 bytes and drops the rest, so anything past
    // them is not part of the password however many characters it looks like.
    public const int MaximumBytes = 72;
}
