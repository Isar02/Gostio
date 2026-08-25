using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Messaging;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PaymentNoticeTests(DatabaseFixture fixture)
{
    private readonly PaymentWorkspace workspace = new(fixture);

    private static DateOnly InAMonth => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task MoneyArrivingTellsTheGuestAndTheHost()
    {
        var (host, guest, booked, payment) = await AChargeAsync();

        var notices = await workspace.SucceedWatchedAsync(payment);

        Assert.All(
            notices.Of<NotificationMessage>(),
            raised => Assert.Equal(booked, raised.ReservationId));

        Assert.Equal(
            [guest, host],
            notices.Of<NotificationMessage>()
                .Where(raised => raised.Type == NotificationType.PaymentSucceeded)
                .Select(raised => raised.UserId));
    }

    // The charge confirmed the booking, and a guest is owed that in the words a
    // host's confirmation would have used.
    [Fact]
    public async Task AChargeThatConfirmsTheBookingSaysSoAsWell()
    {
        var (_, guest, booked, payment) = await AChargeAsync();

        var notices = await workspace.SucceedWatchedAsync(payment);

        var mine = notices.Of<NotificationMessage>()
            .Where(raised => raised.UserId == guest && raised.ReservationId == booked)
            .Select(raised => raised.Type)
            .ToArray();

        Assert.Contains(NotificationType.PaymentSucceeded, mine);
        Assert.Contains(NotificationType.ReservationStatusChanged, mine);
    }

    // Cancelled while the charge was in flight, so it confirmed nothing.
    [Fact]
    public async Task AChargeThatConfirmedNothingAnnouncesOnlyTheMoney()
    {
        var (_, guest, booked, payment) = await AChargeAsync();

        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        var notices = await workspace.SucceedWatchedAsync(payment);

        var mine = notices.Of<NotificationMessage>()
            .Where(raised => raised.ReservationId == booked)
            .Select(raised => raised.Type)
            .ToArray();

        Assert.Contains(NotificationType.PaymentSucceeded, mine);
        Assert.DoesNotContain(NotificationType.ReservationStatusChanged, mine);
    }

    // Told twice that the money arrived reads as two charges.
    [Fact]
    public async Task ASettlementDeliveredTwiceIsAnnouncedOnce()
    {
        var (_, _, _, payment) = await AChargeAsync();

        await workspace.SucceedAsync(payment);

        var notices = await workspace.SucceedWatchedAsync(payment);

        Assert.Empty(notices.Sent);
    }

    // The host was told when it ended and never held the money.
    [Fact]
    public async Task ARefundTellsTheGuestAlone()
    {
        await workspace.DrainRefundsAsync();

        var (_, guest, booked, payment) = await AChargeAsync();

        await workspace.SucceedAsync(payment);
        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");

        var (swept, notices) = await workspace.SweepRefundsWatchedAsync();

        Assert.Equal(1, swept.Settled);

        var raised = Assert.Single(notices.Of<NotificationMessage>());

        Assert.Equal(guest, raised.UserId);
        Assert.Equal(NotificationType.RefundProcessed, raised.Type);
        Assert.Equal(booked, raised.ReservationId);
    }

    [Fact]
    public async Task ASecondRefundPassAnnouncesNothingAgain()
    {
        await workspace.DrainRefundsAsync();

        var (_, guest, booked, payment) = await AChargeAsync();

        await workspace.SucceedAsync(payment);
        await workspace.Reservations.CancelAsync(guest, RoleNames.Guest, booked, "Plans changed");
        await workspace.SweepRefundsAsync();

        var (_, notices) = await workspace.SweepRefundsWatchedAsync();

        Assert.Empty(notices.Sent);
    }

    private async Task<(int Host, int Guest, int Booked, int Payment)> AChargeAsync()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(
            guest, listing, InAMonth, nights: 2);
        var started = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        return (host, guest, booked.Id, started.Id);
    }

    private static IReadOnlyList<int> Told(CapturedNotices notices) =>
        [.. notices.Of<NotificationMessage>().Select(raised => raised.UserId)];
}
