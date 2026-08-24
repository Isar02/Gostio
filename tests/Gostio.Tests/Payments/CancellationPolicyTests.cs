using Gostio.Services.Payments;

namespace Gostio.Tests.Payments;

public class CancellationPolicyTests
{
    private static readonly DateTime Booked = new(2026, 6, 1, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void CallingItOffInsideTheGracePeriodGivesEverythingBack()
    {
        var entitlement = CancellationPolicy.For(
            Booked, Booked.AddDays(30), Booked.AddHours(47));

        Assert.Equal(CancellationPolicy.Full, entitlement.Percentage);
        Assert.Contains("grace period", entitlement.Reason, StringComparison.Ordinal);
    }

    [Fact]
    public void AWeekOfNoticeGivesEverythingBack() =>
        Assert.Equal(
            CancellationPolicy.Full,
            CancellationPolicy.For(Booked, Booked.AddDays(30), Booked.AddDays(23)).Percentage);

    [Fact]
    public void LessThanAWeekButMoreThanADayGivesHalfBack() =>
        Assert.Equal(
            CancellationPolicy.Half,
            CancellationPolicy.For(Booked, Booked.AddDays(30), Booked.AddDays(27)).Percentage);

    [Fact]
    public void TheLastDayGivesNothingBack() =>
        Assert.Equal(
            CancellationPolicy.Nothing,
            CancellationPolicy.For(
                Booked, Booked.AddDays(30), Booked.AddDays(30).AddHours(-12)).Percentage);

    // The thresholds are read from the start and not from the cancellation, so
    // the boundary belongs to the guest on both sides of it.
    [Fact]
    public void EachThresholdIsInclusive()
    {
        var starts = Booked.AddDays(30);

        Assert.Equal(
            CancellationPolicy.Full,
            CancellationPolicy.For(Booked, starts, starts - CancellationPolicy.FullRefundNotice)
                .Percentage);

        Assert.Equal(
            CancellationPolicy.Half,
            CancellationPolicy.For(Booked, starts, starts - CancellationPolicy.HalfRefundNotice)
                .Percentage);
    }

    // A booking made for something that begins almost at once gets the short
    // window rather than two days to think about a stay already under way.
    [Fact]
    public void ABookingForSomethingImminentGetsTheShortGracePeriod()
    {
        var starts = Booked.AddHours(10);

        Assert.Equal(
            Booked + CancellationPolicy.ShortGraceWindow,
            CancellationPolicy.GraceEndsAt(Booked, starts));

        Assert.Equal(
            CancellationPolicy.Full,
            CancellationPolicy.For(Booked, starts, Booked.AddHours(3)).Percentage);

        Assert.Equal(
            CancellationPolicy.Nothing,
            CancellationPolicy.For(Booked, starts, Booked.AddHours(5)).Percentage);
    }

    [Fact]
    public void NoGracePeriodOutlivesWhatItAppliesTo()
    {
        var starts = Booked.AddHours(2);

        Assert.Equal(starts, CancellationPolicy.GraceEndsAt(Booked, starts));

        Assert.Equal(
            CancellationPolicy.Nothing,
            CancellationPolicy.For(Booked, starts, starts.AddMinutes(1)).Percentage);
    }

    [Fact]
    public void TheOddHalfFallsToTheGuest() =>
        Assert.Equal(50.01m, CancellationPolicy.AmountOf(100.01m, CancellationPolicy.Half));

    [Fact]
    public void TheEndsOfTheScaleAreExact()
    {
        Assert.Equal(0m, CancellationPolicy.AmountOf(320m, CancellationPolicy.Nothing));
        Assert.Equal(320m, CancellationPolicy.AmountOf(320m, CancellationPolicy.Full));
    }
}
