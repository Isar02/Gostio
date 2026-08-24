using Gostio.Services.Reservations;

namespace Gostio.Tests.Reservations;

public class ReservationPricingTests
{
    private static readonly DateOnly June1 = new(2026, 6, 1);

    [Fact]
    public void AStayWithoutOverridesCostsTheBasePriceOnEveryNight() =>
        Assert.Equal(300m, ReservationPricing.TotalForNights(June1, June1.AddDays(3), 100m, []));

    [Fact]
    public void TheNightOfTheCheckOutDayIsNotCharged() =>
        Assert.Equal(100m, ReservationPricing.TotalForNights(June1, June1.AddDays(1), 100m, []));

    [Fact]
    public void AnOverrideCoveringEveryNightReplacesTheBasePrice() =>
        Assert.Equal(
            240m,
            ReservationPricing.TotalForNights(
                June1,
                June1.AddDays(3),
                100m,
                [new PricedRange(June1, June1.AddDays(2), 80m)]));

    [Fact]
    public void AnOverrideCoveringPartOfTheStayPricesOnlyTheNightsItCovers() =>
        Assert.Equal(
            260m,
            ReservationPricing.TotalForNights(
                June1,
                June1.AddDays(3),
                100m,
                [new PricedRange(June1, June1.AddDays(1), 80m)]));

    [Fact]
    public void TwoOverridesEachPriceTheirOwnNights() =>
        Assert.Equal(
            150m,
            ReservationPricing.TotalForNights(
                June1,
                June1.AddDays(3),
                100m,
                [
                    new PricedRange(June1, June1, 50m),
                    new PricedRange(June1.AddDays(1), June1.AddDays(2), 50m),
                ]));

    [Fact]
    public void AnOverrideEndingBeforeTheStayChangesNothing() =>
        Assert.Equal(
            200m,
            ReservationPricing.TotalForNights(
                June1,
                June1.AddDays(2),
                100m,
                [new PricedRange(June1.AddDays(-5), June1.AddDays(-1), 10m)]));

    [Fact]
    public void AnOverrideOnTheCheckOutDayChangesNothing() =>
        Assert.Equal(
            200m,
            ReservationPricing.TotalForNights(
                June1,
                June1.AddDays(2),
                100m,
                [new PricedRange(June1.AddDays(2), June1.AddDays(4), 10m)]));
}
