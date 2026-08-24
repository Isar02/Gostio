using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PaymentWebhookTests(DatabaseFixture fixture)
{
    private const string Succeeded = "payment_intent.succeeded";

    private readonly PaymentWorkspace workspace = new(fixture);

    private readonly DatabaseFixture fixture = fixture;

    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    // The endpoint carries no token, so the signature is the whole of its
    // authentication and a body that fails it must change nothing.
    [Fact]
    public async Task ABodySignedWithTheWrongSecretIsRefused()
    {
        var (booked, payment) = await APendingChargeAsync();
        var payload = StripeEvents.Payload(Succeeded, FakePaymentGateway.IntentOf(payment));

        await Assert.ThrowsAsync<ValidationException>(() => workspace.ReceiveAsync(
            payload, StripeEvents.SignatureFor(payload, "whsec_somebody_elses_secret")));

        Assert.Equal(
            PaymentStatus.Pending,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);
    }

    [Fact]
    public async Task ABodyWithNoSignatureAtAllIsRefused()
    {
        var (booked, payment) = await APendingChargeAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.ReceiveAsync(
            StripeEvents.Payload(Succeeded, FakePaymentGateway.IntentOf(payment)),
            signature: null));

        Assert.Equal(
            PaymentStatus.Pending,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);
    }

    [Fact]
    public async Task ASignedSuccessSettlesTheChargeAndConfirmsTheBooking()
    {
        var (booked, payment) = await APendingChargeAsync();

        await ReceiveAsync(StripeEvents.Payload(Succeeded, FakePaymentGateway.IntentOf(payment)));

        Assert.Equal(
            PaymentStatus.Succeeded,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);

        Assert.Equal(
            ReservationStatusCode.Confirmed,
            await workspace.Reservations.StatusOfAsync(booked));
    }

    [Fact]
    public async Task ASignedDeclineKeepsTheChargeOpenAndKeepsItsWords()
    {
        var (booked, payment) = await APendingChargeAsync();

        await ReceiveAsync(StripeEvents.Payload(
            "payment_intent.payment_failed",
            FakePaymentGateway.IntentOf(payment),
            declineMessage: "Your card has insufficient funds."));

        var stored = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(PaymentStatus.Pending, stored.Status);
        Assert.Equal("Your card has insufficient funds.", stored.FailureReason);
    }

    // Stripe sends far more than the three events this acts on. Refusing one
    // would make the processor retry something that will never be handled.
    [Fact]
    public async Task AnEventThisApplicationDoesNotActOnIsAccepted()
    {
        var (booked, payment) = await APendingChargeAsync();

        await ReceiveAsync(
            StripeEvents.Payload("charge.updated", FakePaymentGateway.IntentOf(payment)));

        Assert.Equal(
            PaymentStatus.Pending,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);
    }

    private Task ReceiveAsync(string payload) =>
        workspace.ReceiveAsync(
            payload, StripeEvents.SignatureFor(payload, fixture.Stripe.WebhookSecret));

    private async Task<(int Booked, int Payment)> APendingChargeAsync()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        return (booked.Id, payment.Id);
    }
}
