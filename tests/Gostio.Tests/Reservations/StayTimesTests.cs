using Gostio.Services.Reservations;

namespace Gostio.Tests.Reservations;

public class StayTimesTests
{
    private static readonly DateOnly Summer = new(2026, 7, 15);

    private static readonly DateOnly Winter = new(2026, 1, 15);

    [Fact]
    public void CheckInIsTheCountrysAfternoonAndNotTheServersInSummer() =>
        Assert.Equal(
            new DateTime(2026, 7, 15, 12, 0, 0, DateTimeKind.Utc),
            StayTimes.BeginsAt(Summer));

    [Fact]
    public void CheckInIsTheCountrysAfternoonAndNotTheServersInWinter() =>
        Assert.Equal(
            new DateTime(2026, 1, 15, 13, 0, 0, DateTimeKind.Utc),
            StayTimes.BeginsAt(Winter));

    [Fact]
    public void ADayBeginsAtTheCountrysMidnightAndNotTheServersInSummer() =>
        Assert.Equal(
            new DateTime(2026, 7, 14, 22, 0, 0, DateTimeKind.Utc),
            StayTimes.StartOfDay(Summer));

    [Fact]
    public void ADayBeginsAtTheCountrysMidnightAndNotTheServersInWinter() =>
        Assert.Equal(
            new DateTime(2026, 1, 14, 23, 0, 0, DateTimeKind.Utc),
            StayTimes.StartOfDay(Winter));

    [Fact]
    public void AStayHasNotBegunAMinuteBeforeCheckIn() =>
        Assert.False(
            StayTimes.HasBegun(Summer, new DateTime(2026, 7, 15, 11, 59, 0, DateTimeKind.Utc)));

    [Fact]
    public void AStayHasBegunOnTheStrokeOfCheckIn() =>
        Assert.True(
            StayTimes.HasBegun(Summer, new DateTime(2026, 7, 15, 12, 0, 0, DateTimeKind.Utc)));

    [Fact]
    public void AStayHasNotEndedAMinuteBeforeTheLocalDayItEndsOn() =>
        Assert.False(StayTimes.HasEnded(
            new DateOnly(2026, 7, 16), new DateTime(2026, 7, 15, 21, 59, 0, DateTimeKind.Utc)));

    [Fact]
    public void AStayHasEndedTheMomentTheLocalDayItEndsOnBegins() =>
        Assert.True(StayTimes.HasEnded(
            new DateOnly(2026, 7, 16), new DateTime(2026, 7, 15, 22, 0, 0, DateTimeKind.Utc)));

    [Fact]
    public void TheHourIsNamedTheSameWayItIsMeasured() =>
        Assert.Equal(
            $"{StayTimes.CheckIn.Hour:00}:{StayTimes.CheckIn.Minute:00}",
            StayTimes.CheckInText);
}
