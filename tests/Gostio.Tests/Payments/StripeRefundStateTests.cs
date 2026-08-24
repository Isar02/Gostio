using Gostio.Services.Payments;

namespace Gostio.Tests.Payments;

public class StripeRefundStateTests
{
    [Theory]
    [InlineData("pending")]
    [InlineData("requires_action")]
    public void ARefundThatHasNotResolvedIsStillPending(string status) =>
        Assert.Equal(GatewayRefundState.Pending, StripeRefundStates.Of(status));

    // A cancelled refund is money that did not go back, which is a failure and
    // not a third outcome, so `RefundStatus` needs no member for it.
    [Theory]
    [InlineData("failed")]
    [InlineData("canceled")]
    public void ARefundThatDidNotHappenIsAFailure(string status) =>
        Assert.Equal(GatewayRefundState.Failed, StripeRefundStates.Of(status));

    [Fact]
    public void OnlyOneStatusMeansTheMoneyWentBack() =>
        Assert.Equal(GatewayRefundState.Succeeded, StripeRefundStates.Of("succeeded"));

    [Fact]
    public void AStatusTheMappingDoesNotKnowStopsTheCall()
    {
        var failure = Assert.Throws<InvalidOperationException>(
            () => StripeRefundStates.Of("reversed"));

        Assert.Contains("reversed", failure.Message, StringComparison.Ordinal);
    }
}
