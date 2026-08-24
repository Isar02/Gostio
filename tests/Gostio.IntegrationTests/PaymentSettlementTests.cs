using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Services.Payments;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PaymentSettlementTests(DatabaseFixture fixture)
{
    private readonly PaymentWorkspace workspace = new(fixture);

    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task AChargeThatWentThroughConfirmsTheBooking()
    {
        var (guest, booked, payment) = await APendingChargeAsync();

        await workspace.SucceedAsync(payment);

        var stored = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(PaymentStatus.Succeeded, stored.Status);
        Assert.NotNull(stored.ProcessedAt);
        Assert.Equal(
            ReservationStatusCode.Confirmed,
            await workspace.Reservations.StatusOfAsync(booked));

        var confirmed = Assert.Single(
            await workspace.Reservations.HistoryOfAsync(booked),
            history => history.NewStatusId == (int)ReservationStatusCode.Confirmed);

        Assert.Null(confirmed.ChangedByUserId);
        Assert.True((await workspace.Reservations.ReadAsync(guest, RoleNames.Guest, booked)).IsPaid);
    }

    // A redelivery is the ordinary case rather than the exception, so the second
    // one has to write nothing at all: not the payment, not a second trail row.
    [Fact]
    public async Task TheSameEventTwiceChangesNothingTheSecondTime()
    {
        var (_, booked, payment) = await APendingChargeAsync();

        await workspace.SucceedAsync(payment);

        var afterOne = Assert.Single(await workspace.PaymentsOfAsync(booked));
        var trailAfterOne = await workspace.Reservations.HistoryOfAsync(booked);

        await workspace.SucceedAsync(payment);

        var afterTwo = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(afterOne.ProcessedAt, afterTwo.ProcessedAt);
        Assert.Equal(
            trailAfterOne.Count, (await workspace.Reservations.HistoryOfAsync(booked)).Count);
    }

    [Fact]
    public async Task AnOutcomeForAChargeNoPaymentNamesIsIgnored()
    {
        var (_, booked, _) = await APendingChargeAsync();

        await workspace.SettleAsync(
            new PaymentOutcomeReport("pi_test_nobody", PaymentOutcome.Succeeded, null));

        Assert.Equal(
            PaymentStatus.Pending,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);
    }

    [Fact]
    public async Task ADeclineKeepsTheChargeOpenAndKeepsItsWords()
    {
        var (_, booked, payment) = await APendingChargeAsync();

        await workspace.SettleAsync(new PaymentOutcomeReport(
            FakePaymentGateway.IntentOf(payment), PaymentOutcome.Failed, "Your card was declined."));

        var stored = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(PaymentStatus.Pending, stored.Status);
        Assert.Null(stored.ProcessedAt);
        Assert.Equal("Your card was declined.", stored.FailureReason);
        Assert.Equal(
            ReservationStatusCode.Pending,
            await workspace.Reservations.StatusOfAsync(booked));
    }

    [Fact]
    public async Task ACancelledChargeEndsThePaymentAndLeavesTheBooking()
    {
        var (_, booked, payment) = await APendingChargeAsync();

        await workspace.SettleAsync(new PaymentOutcomeReport(
            FakePaymentGateway.IntentOf(payment), PaymentOutcome.Cancelled, null));

        var stored = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(PaymentStatus.Cancelled, stored.Status);
        Assert.NotNull(stored.ProcessedAt);
        Assert.Equal(
            ReservationStatusCode.Pending,
            await workspace.Reservations.StatusOfAsync(booked));
    }

    // The charge was in flight when the booking ended. The money moved, so the
    // payment says so, and the booking stays where it ended holding money it
    // owes back — which is the refunds' half of this and not the webhook's.
    [Fact]
    public async Task AChargeThatLandedOnAnEndedBookingStillStands()
    {
        var (_, booked, payment) = await APendingChargeAsync();

        await workspace.Reservations.CancelAsync(booked);
        await workspace.SucceedAsync(payment);

        Assert.Equal(
            PaymentStatus.Succeeded,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);

        Assert.Equal(
            ReservationStatusCode.Cancelled,
            await workspace.Reservations.StatusOfAsync(booked));
    }

    [Fact]
    public async Task ABookingTheHostConfirmedIsConfirmedOnce()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.Reservations.ConfirmAsync(host, RoleNames.Host, booked.Id);
        await workspace.SucceedAsync(payment.Id);

        Assert.Equal(
            PaymentStatus.Succeeded,
            Assert.Single(await workspace.PaymentsOfAsync(booked.Id)).Status);

        var confirmed = Assert.Single(
            await workspace.Reservations.HistoryOfAsync(booked.Id),
            history => history.NewStatusId == (int)ReservationStatusCode.Confirmed);

        Assert.Equal(host, confirmed.ChangedByUserId);
    }

    private async Task<(int Guest, int Booked, int Payment)> APendingChargeAsync()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        return (guest, booked.Id, payment.Id);
    }
}
