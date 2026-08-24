namespace Gostio.Model.Validation;

// An amount is sent to a card processor in minor units, so the exponent of the
// currency decides the arithmetic. Every code here has two decimal places, which
// is also what the amount columns store, so one multiplier serves all of them. A
// currency with a different exponent — the yen has none, the dinar has three —
// would make that multiplier silently wrong by a factor of a hundred, so an
// unknown code is refused where it is read rather than assumed here.
public static class Currencies
{
    public const int MinorUnitsPerUnit = 100;

    public const long MaximumMinorUnits = 99_999_999;

    // The smallest charge each processor accepts. A charge under it is refused
    // by the processor, so it is refused before a row is written for it.
    private static readonly Dictionary<string, decimal> SmallestCharges =
        new(StringComparer.OrdinalIgnoreCase)
        {
            ["bam"] = 1.00m,
            ["chf"] = 0.50m,
            ["eur"] = 0.50m,
            ["gbp"] = 0.30m,
            ["usd"] = 0.50m,
        };

    public static IReadOnlyCollection<string> Supported => [.. SmallestCharges.Keys.Order()];

    public static bool IsSupported(string code) => SmallestCharges.ContainsKey(code);

    public static string Normalize(string code) =>
        SmallestCharges.ContainsKey(code)
            ? code.ToLowerInvariant()
            : throw Unsupported(code);

    public static decimal SmallestChargeIn(string code) =>
        SmallestCharges.TryGetValue(code, out var smallest)
            ? smallest
            : throw Unsupported(code);

    public static decimal LargestChargeIn(string code)
    {
        _ = SmallestChargeIn(code);

        return MaximumMinorUnits / (decimal)MinorUnitsPerUnit;
    }

    private static InvalidOperationException Unsupported(string code) =>
        new(
            $"The currency '{code}' is not one this application charges in. "
                + $"It handles {string.Join(", ", Supported)}.");
}
