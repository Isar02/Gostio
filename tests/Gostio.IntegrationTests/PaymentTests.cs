using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Validation;
using Gostio.Services.Payments;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PaymentTests(DatabaseFixture fixture)
{
    private readonly PaymentWorkspace workspace = new(fixture);

    private readonly DatabaseFixture fixture = fixture;

    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task TheGuestPaysWhatTheServerPriced()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync(price: 120m);
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 3);

        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        Assert.Equal(booked.TotalPrice, payment.Amount);
        Assert.Equal(fixture.Stripe.Currency, payment.Currency);
        Assert.Equal(fixture.Stripe.PublishableKey, payment.PublishableKey);
        Assert.Equal(nameof(PaymentStatus.Pending), payment.Status);
        Assert.False(string.IsNullOrWhiteSpace(payment.ClientSecret));

        var stored = Assert.Single(await workspace.PaymentsOfAsync(booked.Id));

        Assert.Equal(booked.TotalPrice, stored.Amount);
        Assert.Equal(FakePaymentGateway.IntentOf(stored.Id), stored.StripePaymentIntentId);
    }

    // A guest who closed the card sheet asks again, and the answer is the charge
    // that already exists rather than a second one against the same booking.
    [Fact]
    public async Task AskingTwiceHandsBackTheSameCharge()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        var first = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);
        var second = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        Assert.Equal(first.Id, second.Id);
        Assert.Equal(first.ClientSecret, second.ClientSecret);
        Assert.Single(await workspace.PaymentsOfAsync(booked.Id));
        Assert.Equal([first.Id], workspace.Gateway.Created);
    }

    [Fact]
    public async Task OnlyTheGuestWhoBookedPays()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var stranger = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.StartAsync(host, RoleNames.Host, booked.Id));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.StartAsync(stranger, RoleNames.Guest, booked.Id));

        Assert.Empty(await workspace.PaymentsOfAsync(booked.Id));
    }

    [Fact]
    public async Task ABookingThatIsOverIsNotPaidFor()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.Reservations.CancelAsync(booked.Id);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.StartAsync(guest, RoleNames.Guest, booked.Id));
    }

    [Fact]
    public async Task AHoldThatRanOutIsNotPaidFor()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.Reservations.LapseAsync(booked.Id);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.StartAsync(guest, RoleNames.Guest, booked.Id));
    }

    [Fact]
    public async Task ABookingTheHostConfirmedIsStillPaidFor()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.Reservations.ConfirmAsync(host, RoleNames.Host, booked.Id);

        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        Assert.Equal(booked.TotalPrice, payment.Amount);
    }

    [Fact]
    public async Task ABookingAlreadyPaidForIsNotPaidForTwice()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.SucceedAsync(payment.Id);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.StartAsync(guest, RoleNames.Guest, booked.Id));

        Assert.Single(await workspace.PaymentsOfAsync(booked.Id));
    }

    [Fact]
    public async Task AChargeTheProcessorSettledIsNotReopened()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        workspace.Gateway.Settle(payment.Id, GatewayIntentState.Succeeded);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.StartAsync(guest, RoleNames.Guest, booked.Id));
    }

    // The processor refuses an amount under its floor, and a row written for one
    // it will never take would block every retry while never succeeding itself.
    // A term rather than a stay, because a stay carries a cleaning fee that
    // cannot be priced down this far.
    [Fact]
    public async Task ABookingUnderTheSmallestChargeOpensNoPaymentAtAll()
    {
        var (_, slot) = await workspace.Reservations.ATermAsync(
            capacity: 4, startsAt: DateTime.UtcNow.AddDays(10), price: 0.01m);

        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookTermAsync(guest, slot, guestCount: 1);

        Assert.True(booked.TotalPrice < Currencies.SmallestChargeIn(fixture.Stripe.Currency));

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.StartAsync(guest, RoleNames.Guest, booked.Id));

        Assert.Empty(await workspace.PaymentsOfAsync(booked.Id));
        Assert.Empty(workspace.Gateway.Created);
    }

    [Fact]
    public async Task ABookingOverTheLargestChargeOpensNoPaymentAtAll()
    {
        var largest = Currencies.LargestChargeIn(fixture.Stripe.Currency);
        var (_, slot) = await workspace.Reservations.ATermAsync(
            capacity: 4, startsAt: DateTime.UtcNow.AddDays(10), price: largest + 0.01m);

        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookTermAsync(guest, slot, guestCount: 1);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.StartAsync(guest, RoleNames.Guest, booked.Id));

        Assert.Empty(await workspace.PaymentsOfAsync(booked.Id));
        Assert.Empty(workspace.Gateway.Created);
    }

    [Fact]
    public async Task ABookingNobodyPaidForHasNoPaymentToRead()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(guest, RoleNames.Guest, booked.Id));
    }

    [Fact]
    public async Task TheHostReadsThePaymentWithoutItsSecret()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        var started = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);
        var read = await workspace.ReadAsync(host, RoleNames.Host, booked.Id);

        Assert.Equal(started.Id, read.Id);
        Assert.Equal(started.Amount, read.Amount);
        Assert.Null(read.ClientSecret);
        Assert.Null(read.PublishableKey);
    }

    [Fact]
    public async Task AStrangerReadsNoPaymentAtAll()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var stranger = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stranger, RoleNames.Guest, booked.Id));
    }

    // Two taps at once. Both wait on the lock the first one takes over the
    // booking, so the second reads the row the first wrote and one charge is
    // opened. Checked by removing the lock and watching a second row appear.
    [Fact]
    public async Task TwoTapsAtOnceOpenOneCharge()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        var barrier = new CommandBarrier(2, "[Reservations] WITH (UPDLOCK, HOLDLOCK)");

        var results = await Task.WhenAll(
            workspace.StartAsync(guest, RoleNames.Guest, booked.Id, barrier),
            workspace.StartAsync(guest, RoleNames.Guest, booked.Id, barrier));

        Assert.Equal(2, barrier.Arrived);
        Assert.Equal(results[0].Id, results[1].Id);
        Assert.Single(await workspace.PaymentsOfAsync(booked.Id));
    }
}
