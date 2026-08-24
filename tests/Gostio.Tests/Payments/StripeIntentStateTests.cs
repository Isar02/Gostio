using Gostio.Services.Payments;

namespace Gostio.Tests.Payments;

public class StripeIntentStateTests
{
    [Theory]
    [InlineData("requires_payment_method")]
    [InlineData("requires_confirmation")]
    [InlineData("requires_action")]
    [InlineData("processing")]
    [InlineData("requires_capture")]
    public void EveryUnfinishedStatusIsOneState(string status) =>
        Assert.Equal(GatewayIntentState.Open, StripeIntentStates.Of(status));

    [Fact]
    public void OnlyTheTwoTerminalStatusesEndACharge()
    {
        Assert.Equal(GatewayIntentState.Succeeded, StripeIntentStates.Of("succeeded"));
        Assert.Equal(GatewayIntentState.Cancelled, StripeIntentStates.Of("canceled"));
    }

    // Folding an unknown status into the nearest one records a charge that may
    // never have happened, so it stops the call and names what it was told.
    [Fact]
    public void AStatusTheMappingDoesNotKnowStopsTheCall()
    {
        var failure = Assert.Throws<InvalidOperationException>(
            () => StripeIntentStates.Of("requires_source"));

        Assert.Contains("requires_source", failure.Message, StringComparison.Ordinal);
    }
}
