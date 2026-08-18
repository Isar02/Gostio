namespace Gostio.Services.Database.Configurations;

// Kept in one place so the same concept never gets two different sizes.
internal static class ColumnLengths
{
    public const int Name = 100;

    public const int IsoCode = 2;

    public const int Username = 50;

    // The longest address RFC 5321 allows.
    public const int Email = 254;

    public const int PhoneNumber = 30;

    // A BCrypt hash is 60 characters; the rest is headroom for an algorithm change.
    public const int PasswordHash = 100;

    public const int Reason = 1000;
}
