using Gostio.Services.Reservations;

namespace Gostio.Tests.Reservations;

public class ReservationHoldTests
{
    private static readonly DateTime Now = new(2026, 6, 1, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void AStayFarAheadGetsTheWholeWindow() =>
        Assert.Equal(
            Now + ReservationHold.Window,
            ReservationHold.Deadline(Now, Now.AddDays(30)));

    [Fact]
    public void AHoldNeverOutlivesWhatItHolds() =>
        Assert.Equal(
            Now.AddHours(3),
            ReservationHold.Deadline(Now, Now.AddHours(3)));

    [Fact]
    public void SomethingStartingExactlyWhenTheWindowEndsLeavesTheWindowAlone() =>
        Assert.Equal(
            Now + ReservationHold.Window,
            ReservationHold.Deadline(Now, Now + ReservationHold.Window));

    [Fact]
    public void AStartAlreadyBehindDoesNotShortenTheWindow() =>
        Assert.Equal(
            Now + ReservationHold.Window,
            ReservationHold.Deadline(Now, Now.Date));

    [Fact]
    public void TheDeadlineIsAlwaysAfterTheMomentItWasTakenFrom() =>
        Assert.All(
            new[] { Now.AddDays(-4), Now, Now.AddSeconds(1), Now.AddDays(9) },
            start => Assert.True(ReservationHold.Deadline(Now, start) > Now));
}
