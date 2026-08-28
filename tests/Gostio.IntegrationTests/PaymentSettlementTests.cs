using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Services.Payments;
using Gostio.Services.Reservations;

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
    // payment says so, the booking stays where it ended, and the same row a
    // cancellation writes says how much of it goes back.
    [Fact]
    public async Task AChargeThatLandedOnAnEndedBookingIsOwedBack()
    {
        var (_, booked, payment) = await APendingChargeAsync();

        await workspace.Reservations.CancelAsync(booked);
        await workspace.SucceedAsync(payment);

        var charge = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(PaymentStatus.Succeeded, charge.Status);
        Assert.Equal(
            ReservationStatusCode.Cancelled,
            await workspace.Reservations.StatusOfAsync(booked));

        var owed = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(RefundStatus.Pending, owed.Status);
        Assert.Equal(charge.Amount, owed.Amount);
    }

    // The booking was cancelled outside its grace period and close enough to the
    // stay to owe only half, and the late charge is held to that rather than to
    // the thresholds as they read now.
    [Fact]
    public async Task ALateChargeIsOwedBackByThePolicyAtTheTimeItWasCalledOff()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();

        var booked = await workspace.Reservations.BookStayAsync(
            guest, listing, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(3)), nights: 2);

        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.Reservations.AgeAsync(booked.Id, TimeSpan.FromDays(5));
        await workspace.Reservations.CancelAsync(
            guest, RoleNames.Guest, booked.Id, ReservationHold.RanOut);
        await workspace.SucceedAsync(payment.Id);

        var owed = Assert.Single(await workspace.RefundsOfAsync(booked.Id));

        Assert.Equal(
            CancellationPolicy.AmountOf(payment.Amount, CancellationPolicy.Half), owed.Amount);
    }

    [Fact]
    public async Task AChargeOnAConfirmedBookingIsOwedNothing()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.Reservations.ConfirmAsync(host, RoleNames.Host, booked.Id);
        await workspace.SucceedAsync(payment.Id);

        Assert.Empty(await workspace.RefundsOfAsync(booked.Id));
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

    [Fact]
    public async Task AChargeThatSettledAfterTheHoldRanOutEndsTheBookingAndOwesItBack()
    {
        var (_, booked, payment) = await APendingChargeAsync();

        await workspace.Reservations.LapseAsync(booked);
        await workspace.SucceedAsync(payment);

        var charge = Assert.Single(await workspace.PaymentsOfAsync(booked));

        Assert.Equal(PaymentStatus.Succeeded, charge.Status);
        Assert.Equal(
            ReservationStatusCode.Cancelled,
            await workspace.Reservations.StatusOfAsync(booked));

        var ended = Assert.Single(
            await workspace.Reservations.HistoryOfAsync(booked),
            history => history.NewStatusId == (int)ReservationStatusCode.Cancelled);

        Assert.Null(ended.ChangedByUserId);
        Assert.Equal(charge.Amount, Assert.Single(await workspace.RefundsOfAsync(booked)).Amount);
    }

    [Fact]
    public async Task AChargeOnALapsedHoldLeavesOneLiveBookingOnTheTerm()
    {
        var (_, slot) = await workspace.Reservations.ATermAsync(6, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.Reservations.AGuestAsync();
        var first = await workspace.Reservations.BookTermAsync(guest, slot, guestCount: 1);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, first.Id);

        await workspace.Reservations.LapseAsync(first.Id);

        var barrier = new CommandBarrier(2, "UPDLOCK", "[Experiences]");
        var settlement = workspace.SucceedAsync(payment.Id, barrier);
        var replacement = workspace.Reservations.BookTermAsync(
            guest, slot, guestCount: 1, barrier);

        await Task.WhenAll(settlement, replacement);

        Assert.Equal(2, barrier.Arrived);

        var second = await replacement;

        Assert.Equal(
            ReservationStatusCode.Cancelled,
            await workspace.Reservations.StatusOfAsync(first.Id));

        Assert.Equal(
            ReservationStatusCode.Pending,
            await workspace.Reservations.StatusOfAsync(second.Id));

        Assert.Single(await workspace.RefundsOfAsync(first.Id));
    }

    [Fact]
    public async Task AChargeAfterAStartTimeExpiryIsFullyOwedBackEvenAfterTheSweep()
    {
        var (_, slot) = await workspace.Reservations.ATermAsync(
            6, DateTime.UtcNow.AddHours(3));
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookTermAsync(guest, slot, guestCount: 1);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.Reservations.LapseAtTheTermStartAsync(booked.Id);

        var swept = await workspace.Reservations.SweepAsync();

        Assert.True(swept.Expired >= 1);

        await workspace.SucceedAsync(payment.Id);

        var refund = Assert.Single(await workspace.RefundsOfAsync(booked.Id));

        Assert.Equal(payment.Amount, refund.Amount);
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
