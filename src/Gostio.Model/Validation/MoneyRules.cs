namespace Gostio.Model.Validation;

// The column holds far more than these bounds allow. They are what an amount
// can plausibly be, so a typed-in extra digit is refused under its own field.
public static class MoneyRules
{
    public const double SmallestAmount = 0.01;

    public const double LargestAmount = 1_000_000;
}
