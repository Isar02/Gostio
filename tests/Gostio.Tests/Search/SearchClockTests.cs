using Gostio.Services.Search;

namespace Gostio.Tests.Search;

public class SearchClockTests
{
    private const int Moments = 100_000;

    // The measurement this exists for: the same loop against `DateTime.UtcNow`
    // hands the same instant out again and again because the call is faster
    // than the clock advances.
    [Fact]
    public void NoMomentIsHandedOutTwice()
    {
        var moments = Taken(new(TimeProvider.System), Moments);

        Assert.Equal(Moments, moments.Distinct().Count());
    }

    [Fact]
    public void EveryMomentIsLaterThanTheOneBeforeIt()
    {
        var moments = Taken(new(TimeProvider.System), Moments);

        Assert.All(
            moments.Zip(moments.Skip(1)),
            pair => Assert.True(pair.Second > pair.First));
    }

    [Fact]
    public async Task MomentsTakenAtOnceAreAllDifferent()
    {
        var clock = new SearchClock(TimeProvider.System);

        var callers = await Task.WhenAll(
            Enumerable.Range(0, 8).Select(_ => Task.Run(() => Taken(clock, Moments / 8))));

        var moments = callers.SelectMany(taken => taken).ToList();

        Assert.Equal(moments.Count, moments.Distinct().Count());
    }

    // A clock that never repeats itself could satisfy every test above by
    // counting rather than by telling the time.
    [Fact]
    public void TheMomentIsStillTheTime()
    {
        var clock = new SearchClock(TimeProvider.System);
        var before = DateTime.UtcNow;
        var taken = clock.Now();
        var after = DateTime.UtcNow;

        Assert.InRange(taken, before.AddSeconds(-1), after.AddSeconds(1));
        Assert.Equal(DateTimeKind.Utc, taken.Kind);
    }

    // Search windows measure elapsed time, so changing the machine's idea of
    // UTC must not make adjacent searches suddenly hours apart or together.
    [Theory]
    [InlineData(-1)]
    [InlineData(1)]
    public void AWallClockJumpDoesNotMoveElapsedTime(int direction)
    {
        var time = new AdjustableTimeProvider();
        var clock = new SearchClock(time);
        var before = clock.Now();

        time.MoveWallClock(TimeSpan.FromHours(direction));
        time.Advance(TimeSpan.FromMinutes(1));

        Assert.Equal(TimeSpan.FromMinutes(1), clock.Now() - before);
    }

    private static List<DateTime> Taken(SearchClock clock, int count) =>
        [.. Enumerable.Range(0, count).Select(_ => clock.Now())];

    private sealed class AdjustableTimeProvider : TimeProvider
    {
        private DateTimeOffset utcNow = new(2026, 8, 26, 12, 0, 0, TimeSpan.Zero);
        private long timestamp;

        public override long TimestampFrequency => TimeSpan.TicksPerSecond;

        public override DateTimeOffset GetUtcNow() => utcNow;

        public override long GetTimestamp() => timestamp;

        public void MoveWallClock(TimeSpan change) => utcNow += change;

        public void Advance(TimeSpan elapsed) => timestamp += elapsed.Ticks;
    }
}
