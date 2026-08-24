using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Payments;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class RefundTests(DatabaseFixture fixture)
{
    private readonly PaymentWorkspace workspace = new(fixture);

    private readonly DatabaseFixture fixture = fixture;

    private static DateOnly InAMonth => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task CallingOffAPaidBookingInGoodTimeOwesAllOfIt()
    {
        var (guest, booked, payment) = await APaidBookingAsync(bookedDaysAgo: 5);

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        var refund = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(payment.Id, refund.PaymentId);
        Assert.Equal(RefundStatus.Pending, refund.Status);
        Assert.Equal(payment.Amount, refund.Amount);
        Assert.Contains("seven days", refund.Reason, StringComparison.Ordinal);
    }

    [Fact]
    public async Task TheRefundNamesTheRuleAndTheTrailNamesTheGuest()
    {
        var (guest, booked, _) = await APaidBookingAsync(bookedDaysAgo: 5);

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        var refund = Assert.Single(await workspace.RefundsOfAsync(booked));

        var cancelled = Assert.Single(
            await workspace.Reservations.HistoryOfAsync(booked),
            history => history.NewStatusId == (int)ReservationStatusCode.Cancelled);

        Assert.Equal("Plans changed", cancelled.Reason);
        Assert.Equal(guest, cancelled.ChangedByUserId);
        Assert.Equal(cancelled.ChangedAt, refund.CreatedAt);
        Assert.NotEqual(cancelled.Reason, refund.Reason);
    }

    [Fact]
    public async Task CallingItOffInsideTheGracePeriodOwesAllOfIt()
    {
        var (guest, booked, payment) = await APaidBookingAsync(bookedDaysAgo: 0);

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Booked in error");

        var refund = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(payment.Amount, refund.Amount);
        Assert.Contains("grace period", refund.Reason, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ABookingCalledOffLessThanAWeekAheadOwesHalf()
    {
        var checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(3));
        var (guest, booked, payment) = await APaidBookingAsync(bookedDaysAgo: 5, checkIn: checkIn);

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        var refund = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(CancellationPolicy.AmountOf(payment.Amount, 50), refund.Amount);
    }

    // Nothing is owed and no row is written: a refund of zero is one no
    // constraint allows, and why it is zero is the quote's answer.
    [Fact]
    public async Task ABookingCalledOffOnTheLastDayOwesNothing()
    {
        var checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(12));
        var (guest, booked, _) = await APaidBookingAsync(bookedDaysAgo: 5, checkIn: checkIn);

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        Assert.Empty(await workspace.RefundsOfAsync(booked));
    }

    [Fact]
    public async Task ABookingNobodyPaidForOwesNothing()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, InAMonth, nights: 2);

        await workspace.Reservations.CancelAsync(
            guest, RoleNames.Guest, booked.Id, "Plans changed");

        Assert.Empty(await workspace.RefundsOfAsync(booked.Id));
    }

    [Fact]
    public async Task TheRefundFollowsWhatWasChargedAndNotThePrice()
    {
        var (guest, booked, payment) = await APaidBookingAsync(bookedDaysAgo: 5);

        await workspace.ChargeAsync(payment.Id, payment.Amount + 40m);

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        Assert.Equal(
            payment.Amount + 40m,
            Assert.Single(await workspace.RefundsOfAsync(booked)).Amount);
    }

    [Fact]
    public async Task TheQuoteAnswersBeforeAnythingIsCharged()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, InAMonth, nights: 2);

        var quote = await workspace.QuoteAsync(guest, RoleNames.Guest, booked.Id);

        Assert.False(quote.IsPaid);
        Assert.Equal(booked.TotalPrice, quote.Charged);
        Assert.Equal(booked.TotalPrice, quote.Amount);
        Assert.Equal(CancellationPolicy.Full, quote.Percentage);
        Assert.Equal(fixture.Stripe.Currency, quote.Currency);
        Assert.True(quote.GraceEndsAt > booked.CreatedAt);
    }

    [Fact]
    public async Task TheQuoteFollowsTheChargeOnceThereIsOne()
    {
        var (guest, booked, payment) = await APaidBookingAsync(bookedDaysAgo: 5);

        await workspace.ChargeAsync(payment.Id, payment.Amount + 40m);

        var quote = await workspace.QuoteAsync(guest, RoleNames.Guest, booked);

        Assert.True(quote.IsPaid);
        Assert.Equal(payment.Amount + 40m, quote.Charged);
        Assert.Equal(CancellationPolicy.Full, quote.Percentage);
    }

    // A term begins at its own hour rather than on a night, and the policy reads
    // the two through one property. Booking one is what proves the second half.
    [Fact]
    public async Task ATermIsPricedFromTheHourItBegins()
    {
        var (_, slot) = await workspace.Reservations.ATermAsync(
            capacity: 10, startsAt: DateTime.UtcNow.AddDays(3));

        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookTermAsync(guest, slot, guestCount: 2);
        var payment = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.SucceedAsync(payment.Id);
        await workspace.Reservations.AgeAsync(booked.Id, TimeSpan.FromDays(5));

        var quote = await workspace.QuoteAsync(guest, RoleNames.Guest, booked.Id);

        Assert.True(quote.IsPaid);
        Assert.Equal(CancellationPolicy.Half, quote.Percentage);

        await workspace.Reservations.CancelAsync(
            guest, RoleNames.Guest, booked.Id, "Plans changed");

        Assert.Equal(
            CancellationPolicy.AmountOf(payment.Amount, CancellationPolicy.Half),
            Assert.Single(await workspace.RefundsOfAsync(booked.Id)).Amount);
    }

    // Booked ten days ago, called off seven days ago when the stay was still ten
    // days out, and the stay is now three days away. The clock has crossed a
    // threshold since; the quote must not, because a refund was already promised
    // in full and a guest cannot be told on Friday that Monday's promise shrank.
    [Fact]
    public async Task TheQuoteStopsMovingOnceTheBookingIsCalledOff()
    {
        var (guest, booked, payment) = await APaidBookingAsync(
            bookedDaysAgo: 10, checkIn: DateOnly.FromDateTime(DateTime.UtcNow.AddDays(10)));

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        var owed = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(payment.Amount, owed.Amount);

        await workspace.Reservations.MoveTheStayAsync(
            booked, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(5)));

        await workspace.Reservations.BackdateTheCancellationAsync(booked, TimeSpan.FromDays(7));

        var quote = await workspace.QuoteAsync(guest, RoleNames.Guest, booked);

        Assert.Equal(CancellationPolicy.Full, quote.Percentage);
        Assert.Equal(owed.Amount, quote.Amount);
        Assert.True(quote.AsOf < DateTime.UtcNow.AddDays(-6));
    }

    [Fact]
    public async Task TheQuoteFollowsTheClockWhileTheBookingIsLive()
    {
        var (guest, booked, _) = await APaidBookingAsync(bookedDaysAgo: 5);

        var quote = await workspace.QuoteAsync(guest, RoleNames.Guest, booked);

        Assert.True(quote.AsOf > DateTime.UtcNow.AddMinutes(-1));
    }

    [Fact]
    public async Task AStrangerIsQuotedNothing()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var stranger = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, InAMonth, nights: 2);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.QuoteAsync(stranger, RoleNames.Guest, booked.Id));
    }

    private async Task<(int Guest, int Booked, StoredPayment Payment)> APaidBookingAsync(
        int bookedDaysAgo,
        DateOnly? checkIn = null)
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();

        var booked = await workspace.Reservations.BookStayAsync(
            guest, listing, checkIn ?? InAMonth, nights: 2);

        var started = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.SucceedAsync(started.Id);

        if (bookedDaysAgo > 0)
        {
            await workspace.Reservations.AgeAsync(booked.Id, TimeSpan.FromDays(bookedDaysAgo));
        }

        return (guest, booked.Id, Assert.Single(await workspace.PaymentsOfAsync(booked.Id)));
    }
}
