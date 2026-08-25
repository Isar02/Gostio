namespace Gostio.Services.Messaging;

// One second, then two, then four, then eight, then no more attempts.
public static class RetryBackoff
{
    public const int Attempts = 5;

    private static readonly TimeSpan FirstWait = TimeSpan.FromSeconds(1);

    public static TimeSpan After(int attempt)
    {
        if (attempt < 1 || attempt >= Attempts)
        {
            throw new ArgumentOutOfRangeException(
                nameof(attempt),
                attempt,
                $"Only the first {Attempts - 1} attempts are waited on before another.");
        }

        return FirstWait * (1 << (attempt - 1));
    }

    // A listener climbs the same ladder and then stays on its last rung.
    public static TimeSpan Reopening(int attempt) => After(Math.Min(attempt, Attempts - 1));
}
