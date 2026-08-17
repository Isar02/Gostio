namespace Gostio.Services.Database.Configurations;

/// <summary>
/// Column lengths used across the model, kept in one place so that the same
/// concept is not given two different sizes in two different configurations.
/// </summary>
internal static class ColumnLengths
{
    public const int Name = 100;

    public const int IsoCode = 2;

    public const int Username = 50;

    /// <summary>The longest address RFC 5321 allows.</summary>
    public const int Email = 254;

    public const int PhoneNumber = 30;

    /// <summary>A BCrypt hash is 60 characters; the headroom covers a cost or algorithm change.</summary>
    public const int PasswordHash = 100;

    /// <summary>Free text a person types to justify a decision.</summary>
    public const int Reason = 1000;
}
