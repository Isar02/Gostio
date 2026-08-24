using Gostio.Model.Validation;
using Gostio.Services.Configuration;

namespace Gostio.Tests.Payments;

public class CurrencyTests
{
    [Fact]
    public void EverySupportedCurrencyHasASmallestCharge() =>
        Assert.All(
            Currencies.Supported,
            code =>
            {
                Assert.True(Currencies.SmallestChargeIn(code) > 0m);
                Assert.True(Currencies.LargestChargeIn(code) > Currencies.SmallestChargeIn(code));
            });

    // The multiplier is one number for every code the set holds, so a code whose
    // exponent is not two would be charged a hundredfold. It is refused instead.
    [Theory]
    [InlineData("jpy")]
    [InlineData("kwd")]
    [InlineData("xyz")]
    public void ACurrencyThisApplicationDoesNotChargeInIsRefused(string code)
    {
        Assert.False(Currencies.IsSupported(code));

        var failure = Assert.Throws<InvalidOperationException>(
            () => Currencies.SmallestChargeIn(code));

        Assert.Contains(code, failure.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void TheCodeIsReadWithoutRegardToCase()
    {
        Assert.True(Currencies.IsSupported("EUR"));
        Assert.Equal(Currencies.SmallestChargeIn("eur"), Currencies.SmallestChargeIn("EUR"));
        Assert.Equal("eur", Currencies.Normalize("EUR"));
    }

    // Three capabilities that a deployment can hold separately, which is why
    // they are three conditions and not one.
    [Fact]
    public void EachStripeCapabilityAsksOnlyForWhatItNeeds()
    {
        var refundsOnly = Stripe(secret: "sk", publishable: "", webhook: "");

        Assert.True(refundsOnly.CanReachTheProcessor);
        Assert.False(refundsOnly.CanTakeAPayment);
        Assert.False(refundsOnly.CanVerifyAWebhook);

        var charging = Stripe(secret: "sk", publishable: "pk", webhook: "");

        Assert.True(charging.CanTakeAPayment);
        Assert.False(charging.CanVerifyAWebhook);

        var verifying = Stripe(secret: "", publishable: "", webhook: "whsec");

        Assert.True(verifying.CanVerifyAWebhook);
        Assert.False(verifying.CanTakeAPayment);
    }

    [Fact]
    public void TheProcessorCannotBeReachedWithoutTheSecretKey()
    {
        var none = Stripe(secret: "", publishable: "pk", webhook: "");

        Assert.False(none.CanReachTheProcessor);
        Assert.False(none.CanTakeAPayment);
        Assert.False(none.CanVerifyAWebhook);
    }

    private static StripeSettings Stripe(string secret, string publishable, string webhook) =>
        new()
        {
            SecretKey = secret,
            PublishableKey = publishable,
            WebhookSecret = webhook,
            Currency = "eur",
        };
}
