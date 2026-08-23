namespace Gostio.Model.Validation;

// One place, so the same concept never gets two different sizes. It sits in
// the model rather than beside the entity configuration because a request DTO
// has to state the same bound: a value that passes validation and is then
// refused by the column behind it is a five hundred where a four hundred
// belongs.
public static class ColumnLengths
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
