using System.Text.RegularExpressions;

namespace Gostio.Model.Validation;

public static partial class PhoneNumbers
{
    public const string Message =
        "Enter a phone number with its country code, as +387 61 234 567 or "
        + "+49 170 1234567. A number without one is read as Bosnian: 061 234 567.";

    private const string BosniaCode = "+387";

    public static bool IsValid(string? number) =>
        string.IsNullOrWhiteSpace(number) || Normalise(number) is not null;

    // The stored form of a number, or null when there is nothing to store.
    // Separators carry no meaning, so they are dropped and two records of one
    // number compare equal.
    public static string? Normalise(string? number)
    {
        if (string.IsNullOrWhiteSpace(number))
        {
            return null;
        }

        var dialled = Separators().Replace(number, string.Empty);

        if (Local().IsMatch(dialled))
        {
            dialled = BosniaCode + dialled[1..];
        }

        return International().IsMatch(dialled) ? dialled : null;
    }

    [GeneratedRegex(@"[\s\-()]")]
    private static partial Regex Separators();

    [GeneratedRegex(@"^0\d{8}$")]
    private static partial Regex Local();

    // E.164: a country code that cannot begin with a zero, and eight to fifteen
    // digits in all.
    [GeneratedRegex(@"^\+[1-9]\d{7,14}$")]
    private static partial Regex International();
}
