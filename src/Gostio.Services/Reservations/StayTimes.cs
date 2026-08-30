using System.Globalization;

namespace Gostio.Services.Reservations;

// A stay is booked in whole days but begins at an hour, and both the hour and
// the day are read on the clock where the guest is standing. The listings are
// all in one country, so check-in is that country's afternoon, a date is that
// country's date, and the UTC each lands on moves with the season.
public static class StayTimes
{
    public static readonly TimeOnly CheckIn = new(14, 0);

    // The hour as a booking that arrives too late is told it, so it is written
    // down once rather than beside the constant that decides it.
    public static readonly string CheckInText =
        CheckIn.ToString("HH':'mm", CultureInfo.InvariantCulture);

    private static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById(
        "Europe/Sarajevo");

    // Both hours are far from either daylight-saving transition, so the local
    // moment each names exists exactly once on every date and is never ambiguous.
    public static DateTime BeginsAt(DateOnly checkInDate) =>
        TimeZoneInfo.ConvertTimeToUtc(checkInDate.ToDateTime(CheckIn), Zone);

    public static DateTime StartOfDay(DateOnly day) =>
        TimeZoneInfo.ConvertTimeToUtc(day.ToDateTime(TimeOnly.MinValue), Zone);

    public static bool HasBegun(DateOnly checkInDate, DateTime now) => BeginsAt(checkInDate) <= now;

    public static bool HasEnded(DateOnly checkOutDate, DateTime now) =>
        checkOutDate <= DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(now, Zone));
}
