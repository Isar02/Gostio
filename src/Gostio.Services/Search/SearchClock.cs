namespace Gostio.Services.Search;

public sealed class SearchClock
{
    private readonly TimeProvider time;
    private readonly long startedAt;
    private readonly long startedOn;

    private long handedOut;

    public SearchClock(TimeProvider time)
    {
        this.time = time;
        startedOn = time.GetUtcNow().UtcTicks;
        startedAt = time.GetTimestamp();
    }

    // Elapsed time cannot jump with the wall clock, and the CAS gives each
    // overlapping caller a distinct moment in the order calls linearize here.
    public DateTime Now()
    {
        while (true)
        {
            var last = Interlocked.Read(ref handedOut);
            var elapsed = time.GetElapsedTime(startedAt).Ticks;
            var next = Math.Max(startedOn + elapsed, last + 1);

            if (Interlocked.CompareExchange(ref handedOut, next, last) == last)
            {
                return new DateTime(next, DateTimeKind.Utc);
            }
        }
    }
}
