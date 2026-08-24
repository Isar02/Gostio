using Gostio.Model.Authorization;
using Gostio.Model.Enums;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PaymentLockOrderTests(DatabaseFixture fixture)
{
    private readonly PaymentWorkspace workspace = new(fixture);

    private static DateOnly InAMonth => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    // A guest calling a booking off and the processor settling its charge touch
    // the same two rows, and both take the booking first so that one queues
    // behind the other rather than each holding what the other wants. What this
    // proves is the queueing, not the deadlock it prevents: taking the lock out
    // of the settlement fails it because only one caller then reaches the lock
    // at all, which is exactly the ordering going away.
    [Fact]
    public async Task ACancellationAndASettlementAtOnceQueueRatherThanDeadlock()
    {
        var (guest, booked, payment) = await APaidBookingAsync();

        var (cancel, settle) = await workspace.CancelWhileSettlingAsync(
            guest, RoleNames.Guest, booked, payment);

        Assert.True(cancel.IsCompletedSuccessfully);
        Assert.True(settle.IsCompletedSuccessfully);
    }

    // Whichever of the two wins, the end is the same: the money moved, the
    // booking is off, and exactly one refund says what goes back. That is the
    // invariant the ordering exists to protect.
    [Fact]
    public async Task EitherOrderEndsWithOneRefundAgainstASettledCharge()
    {
        var (guest, booked, payment) = await APaidBookingAsync();

        await workspace.CancelWhileSettlingAsync(guest, RoleNames.Guest, booked, payment);

        Assert.Equal(
            PaymentStatus.Succeeded,
            Assert.Single(await workspace.PaymentsOfAsync(booked)).Status);

        Assert.Equal(
            ReservationStatusCode.Cancelled,
            await workspace.Reservations.StatusOfAsync(booked));

        Assert.Single(await workspace.RefundsOfAsync(booked));
    }

    // A booking held open long enough to be worth refunding in full, so the
    // invariant above is about one refund rather than about none.
    private async Task<(int Guest, int Booked, int Payment)> APaidBookingAsync()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, InAMonth, nights: 2);
        var started = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        return (guest, booked.Id, started.Id);
    }
}
