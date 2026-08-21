namespace Gostio.Services.Database.Configurations;

// One place, so the same concept never gets two different sizes.
internal static class ColumnLengths
{
    public const int Name = 100;

    public const int Code = 30;

    public const int Title = 200;

    public const int Description = 2000;

    public const int Address = 250;

    public const int IsoCode = 2;

    public const int Username = 50;

    public const int Email = 254;

    public const int PhoneNumber = 30;

    public const int PasswordHash = 100;

    public const int Reason = 1000;

    public const int ExternalId = 255;

    public const int CurrencyCode = 3;

    public const int TokenHash = 128;

    public const int Comment = 1000;

    public const int MessageBody = 2000;

    public const int NotificationBody = 1000;

    public const int NewsBody = 4000;

    public const int SearchTerm = 200;
}
