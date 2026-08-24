namespace Gostio.Services.Payments;

public sealed record RefundEntitlement(int Percentage, string Reason);

// What a guest gets back, decided by two clocks: how long ago they booked and
// how long is left before the thing begins. Both are promises the product makes
// rather than settings a deployment tunes, so they are constants here for the
// same reason `ReservationHold.Window` is one.
public static class CancellationPolicy
{
    public const int Full = 100;

    public const int Half = 50;

    public const int Nothing = 0;

    public static readonly TimeSpan GraceWindow = TimeSpan.FromHours(48);

    public static readonly TimeSpan ShortGraceWindow = TimeSpan.FromHours(4);

    public static readonly TimeSpan ImminentWhenWithin = TimeSpan.FromHours(24);

    public static readonly TimeSpan FullRefundNotice = TimeSpan.FromDays(7);

    public static readonly TimeSpan HalfRefundNotice = TimeSpan.FromHours(24);

    // A booking made for something that starts almost immediately gets the short
    // window, and no window outlives what it applies to: a grace period running
    // past the first night would hand back the price of a stay already under way.
    public static DateTime GraceEndsAt(DateTime createdAt, DateTime startsAt)
    {
        var window = startsAt - createdAt < ImminentWhenWithin ? ShortGraceWindow : GraceWindow;
        var endsAt = createdAt + window;

        return endsAt < startsAt ? endsAt : startsAt;
    }

    public static RefundEntitlement For(DateTime createdAt, DateTime startsAt, DateTime cancelledAt)
    {
        if (cancelledAt < GraceEndsAt(createdAt, startsAt))
        {
            return new RefundEntitlement(
                Full, "Cancelled inside the grace period that follows a booking.");
        }

        var notice = startsAt - cancelledAt;

        if (notice >= FullRefundNotice)
        {
            return new RefundEntitlement(
                Full, "Cancelled at least seven days before it was due to begin.");
        }

        return notice >= HalfRefundNotice
            ? new RefundEntitlement(
                Half, "Cancelled less than seven days, but at least a day, before it was due to "
                    + "begin.")
            : new RefundEntitlement(
                Nothing, "Cancelled less than a day before it was due to begin.");
    }

    // Rounded away from zero, so the half of an odd amount falls to the guest.
    // A percentage is never above a hundred, so this cannot exceed the charge.
    public static decimal AmountOf(decimal charged, int percentage) =>
        decimal.Round(charged * percentage / 100m, 2, MidpointRounding.AwayFromZero);
}
