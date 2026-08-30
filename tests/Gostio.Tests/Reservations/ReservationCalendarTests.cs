using System.Linq.Expressions;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Tests.Reservations;

public class ReservationCalendarTests
{
    private static readonly DateOnly Day = new(2026, 6, 16);

    // 00:30 on the morning of Day where the guest is standing, which is the
    // evening before in UTC.
    private static readonly DateTime JustAfterMidnight =
        new(2026, 6, 15, 22, 30, 0, DateTimeKind.Utc);

    [Fact]
    public void AStayThatEndsOnTheFirstDayOfTheWindowOccupiesNoNightInIt() =>
        Assert.False(Matches(
            ReservationCalendar.OccupiesOnOrAfter(Day), AStay(Day.AddDays(-2), nights: 2)));

    [Fact]
    public void AStayWhoseLastNightOpensTheWindowIsKept() =>
        Assert.True(Matches(
            ReservationCalendar.OccupiesOnOrAfter(Day), AStay(Day.AddDays(-1), nights: 2)));

    [Fact]
    public void AStayThatBeginsOnTheLastDayOfTheWindowIsKept() =>
        Assert.True(Matches(ReservationCalendar.OccupiesOnOrBefore(Day), AStay(Day, nights: 2)));

    [Fact]
    public void AStayThatBeginsAfterTheWindowIsLeftOut() =>
        Assert.False(Matches(
            ReservationCalendar.OccupiesOnOrBefore(Day), AStay(Day.AddDays(1), nights: 2)));

    [Fact]
    public void ATermBelongsToTheDayItStartsOnLocally() =>
        Assert.True(Matches(
            ReservationCalendar.OccupiesOnOrAfter(Day), ATerm(JustAfterMidnight)));

    [Fact]
    public void ATermDoesNotBelongToTheDayItsStoredMomentFallsOn() =>
        Assert.False(Matches(
            ReservationCalendar.OccupiesOnOrBefore(Day.AddDays(-1)), ATerm(JustAfterMidnight)));

    [Fact]
    public void ATermInsideTheWindowIsKeptFromBothEnds() =>
        Assert.All(
            new[]
            {
                ReservationCalendar.OccupiesOnOrAfter(Day),
                ReservationCalendar.OccupiesOnOrBefore(Day),
            },
            predicate => Assert.True(Matches(predicate, ATerm(JustAfterMidnight))));

    [Fact]
    public void ATermAfterTheWindowIsLeftOut() =>
        Assert.False(Matches(
            ReservationCalendar.OccupiesOnOrBefore(Day), ATerm(JustAfterMidnight.AddDays(1))));

    [Fact]
    public void AnArrivalIsTheDayTheStayBegins() =>
        Assert.True(Matches(ReservationCalendar.ArrivesOn(Day), AStay(Day, nights: 2)));

    [Fact]
    public void ADepartureIsTheDayTheStayEndsRatherThanItsLastNight() =>
        Assert.True(Matches(
            ReservationCalendar.DepartsOn(Day.AddDays(2)), AStay(Day, nights: 2)));

    [Fact]
    public void TheDayAStayEndsOnIsNotAnArrival() =>
        Assert.False(Matches(
            ReservationCalendar.ArrivesOn(Day.AddDays(2)), AStay(Day, nights: 2)));

    [Fact]
    public void TheDayAStayBeginsOnIsNotADeparture() =>
        Assert.False(Matches(ReservationCalendar.DepartsOn(Day), AStay(Day, nights: 2)));

    [Fact]
    public void ATermNeitherArrivesNorDeparts() =>
        Assert.All(
            new[] { ReservationCalendar.ArrivesOn(Day), ReservationCalendar.DepartsOn(Day) },
            predicate => Assert.False(Matches(predicate, ATerm(JustAfterMidnight))));

    [Fact]
    public void TheLastRepresentableDayClosesAWindowOverEverything() =>
        Assert.All(
            new[] { AStay(Day, nights: 2), ATerm(JustAfterMidnight) },
            reservation => Assert.True(Matches(
                ReservationCalendar.OccupiesOnOrBefore(DateOnly.MaxValue), reservation)));

    [Fact]
    public void TheFirstRepresentableDayOpensAWindowOverEverything() =>
        Assert.All(
            new[] { AStay(Day, nights: 2), ATerm(JustAfterMidnight) },
            reservation => Assert.True(Matches(
                ReservationCalendar.OccupiesOnOrAfter(DateOnly.MinValue), reservation)));

    private static bool Matches(
        Expression<Func<Reservation, bool>> predicate,
        Reservation reservation) =>
        predicate.Compile()(reservation);

    private static Reservation AStay(DateOnly checkIn, int nights) =>
        new() { CheckInDate = checkIn, CheckOutDate = checkIn.AddDays(nights) };

    private static Reservation ATerm(DateTime startsAt) =>
        new() { ExperienceSlotId = 1, ExperienceSlot = new ExperienceSlot { StartTime = startsAt } };
}
