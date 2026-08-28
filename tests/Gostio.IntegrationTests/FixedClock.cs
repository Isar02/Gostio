namespace Gostio.IntegrationTests;

internal sealed class FixedClock(DateTime now) : TimeProvider
{
    public override DateTimeOffset GetUtcNow() => new(now, TimeSpan.Zero);
}
