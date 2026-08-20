namespace Gostio.Services.Database.Configurations;

// Kept in one place so the same concept never gets two different sizes.
internal static class ColumnLengths
{
    public const int Name = 100;

    // A system identifier a reader matches on, not a sentence.
    public const int Code = 30;

    public const int Title = 200;

    public const int Description = 2000;

    public const int Address = 250;

    public const int IsoCode = 2;

    public const int Username = 50;

    // The longest address RFC 5321 allows.
    public const int Email = 254;

    public const int PhoneNumber = 30;

    // A BCrypt hash is 60 characters; the rest is headroom for an algorithm change.
    public const int PasswordHash = 100;

    public const int Reason = 1000;

    // Issued by the payment provider; Stripe promises no length, so this is the
    // maximum its documentation tells a caller to store.
    public const int ExternalId = 255;

    // ISO 4217.
    public const int CurrencyCode = 3;
}
