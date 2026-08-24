using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Payments;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class RefundSweepTests(DatabaseFixture fixture)
{
    private readonly PaymentWorkspace workspace = new(fixture);

    private static DateOnly InAMonth => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task OnePassHandsOverWhatACancellationOwed()
    {
        await workspace.DrainRefundsAsync();

        var (guest, booked) = await ACancelledPaidBookingAsync();
        var owed = Assert.Single(await workspace.RefundsOfAsync(booked));

        var swept = await workspace.SweepRefundsAsync();

        Assert.Equal(new RefundSweepReport(Sent: 1, Settled: 1, Failed: 0, Waiting: 0), swept);

        var settled = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(RefundStatus.Succeeded, settled.Status);
        Assert.Equal(FakePaymentGateway.RefundOf(owed.Id), settled.StripeRefundId);
        Assert.NotNull(settled.ProcessedAt);
        Assert.Equal([owed.Id], workspace.Gateway.Sent);

        var read = await workspace.ReadRefundAsync(guest, RoleNames.Guest, booked);

        Assert.Equal(settled.Id, read.Id);
        Assert.Equal(nameof(RefundStatus.Succeeded), read.Status);
        Assert.Equal(owed.Amount, read.Amount);
    }

    [Fact]
    public async Task ASecondPassSendsNothingAgain()
    {
        await workspace.DrainRefundsAsync();

        var (_, booked) = await ACancelledPaidBookingAsync();

        await workspace.SweepRefundsAsync();

        var swept = await workspace.SweepRefundsAsync();

        Assert.Equal(new RefundSweepReport(0, 0, 0, 0), swept);
        Assert.Single(workspace.Gateway.Sent);
        Assert.Single(await workspace.RefundsOfAsync(booked));
    }

    // A processor that cannot be reached leaves the row owed, so the next pass
    // is what finishes it rather than a guest chasing their money.
    [Fact]
    public async Task AProcessorThatRefusesLeavesTheRefundOwed()
    {
        await workspace.DrainRefundsAsync();

        var (_, booked) = await ACancelledPaidBookingAsync();

        workspace.Gateway.RefusesTheNextRefund = true;

        Assert.Equal(new RefundSweepReport(0, 0, 0, 0), await workspace.SweepRefundsAsync());
        Assert.Equal(
            RefundStatus.Pending,
            Assert.Single(await workspace.RefundsOfAsync(booked)).Status);

        Assert.Equal(new RefundSweepReport(1, 1, 0, 0), await workspace.SweepRefundsAsync());
        Assert.Equal(
            RefundStatus.Succeeded,
            Assert.Single(await workspace.RefundsOfAsync(booked)).Status);
    }

    // A refund the processor has not resolved is asked about again rather than
    // sent again, and it stays owed until it has an answer.
    [Fact]
    public async Task ARefundStillInFlightIsAskedAboutAgain()
    {
        await workspace.DrainRefundsAsync();

        var (_, booked) = await ACancelledPaidBookingAsync();

        workspace.Gateway.RefundLandsAs = GatewayRefundState.Pending;

        Assert.Equal(new RefundSweepReport(1, 0, 0, 1), await workspace.SweepRefundsAsync());

        var waiting = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(RefundStatus.Pending, waiting.Status);
        Assert.Equal(FakePaymentGateway.RefundOf(waiting.Id), waiting.StripeRefundId);
        Assert.Null(waiting.ProcessedAt);

        workspace.Gateway.SettleRefund(waiting.Id, GatewayRefundState.Succeeded);

        Assert.Equal(new RefundSweepReport(0, 1, 0, 0), await workspace.SweepRefundsAsync());
        Assert.Single(workspace.Gateway.Sent);
        Assert.Equal(
            RefundStatus.Succeeded,
            Assert.Single(await workspace.RefundsOfAsync(booked)).Status);
    }

    [Fact]
    public async Task ARefundTheProcessorTurnedDownIsRecordedAsFailed()
    {
        await workspace.DrainRefundsAsync();

        var (_, booked) = await ACancelledPaidBookingAsync();

        workspace.Gateway.RefundLandsAs = GatewayRefundState.Failed;

        Assert.Equal(new RefundSweepReport(1, 0, 1, 0), await workspace.SweepRefundsAsync());

        var failed = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(RefundStatus.Failed, failed.Status);
        Assert.NotNull(failed.ProcessedAt);
        Assert.Equal("The bank turned it down.", failed.FailureReason);
    }

    [Fact]
    public async Task OnePassSendsNoMoreThanItsBudget()
    {
        await workspace.DrainRefundsAsync();

        await ACancelledPaidBookingAsync();
        await ACancelledPaidBookingAsync();

        Assert.Equal(1, (await workspace.SweepRefundsAsync(batch: 1)).Sent);
        Assert.Equal(1, (await workspace.SweepRefundsAsync(batch: 1)).Sent);
        Assert.Equal(0, (await workspace.SweepRefundsAsync(batch: 1)).Sent);
    }

    // The send went through and the answer never came back, so the row carries no
    // id while the processor already holds the refund. Sending again would pay
    // the guest twice once the idempotency key has aged out, so the pass looks
    // first and adopts what it finds.
    [Fact]
    public async Task ARefundTheProcessorAlreadyHoldsIsAdoptedRatherThanSentAgain()
    {
        await workspace.DrainRefundsAsync();

        var (_, booked) = await ACancelledPaidBookingAsync();
        var owed = Assert.Single(await workspace.RefundsOfAsync(booked));
        var charge = Assert.Single(await workspace.PaymentsOfAsync(booked));

        workspace.Gateway.HoldRefundNobodyHeardAbout(owed.Id, charge.Id);

        Assert.Equal(new RefundSweepReport(0, 1, 0, 0), await workspace.SweepRefundsAsync());

        Assert.Empty(workspace.Gateway.Sent);

        var settled = Assert.Single(await workspace.RefundsOfAsync(booked));

        Assert.Equal(RefundStatus.Succeeded, settled.Status);
        Assert.Equal(FakePaymentGateway.RefundOf(owed.Id), settled.StripeRefundId);
    }

    [Fact]
    public async Task ABookingOwedNothingHasNoRefundToRead()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, InAMonth, nights: 2);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadRefundAsync(guest, RoleNames.Guest, booked.Id));
    }

    private async Task<(int Guest, int Booked)> ACancelledPaidBookingAsync()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, InAMonth, nights: 2);
        var started = await workspace.StartAsync(guest, RoleNames.Guest, booked.Id);

        await workspace.SucceedAsync(started.Id);

        await workspace.Reservations.CancelAsync(
            guest, RoleNames.Guest, booked.Id, "Plans changed");

        return (guest, booked.Id);
    }
}
