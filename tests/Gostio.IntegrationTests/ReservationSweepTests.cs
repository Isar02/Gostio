using Gostio.Model.Authorization;
using Gostio.Model.Enums;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReservationSweepTests(DatabaseFixture fixture)
{
    private const string TheHoldRanOut = "The hold on this booking ran out.";

    private static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    private static DateOnly Soon => Today.AddDays(20);

    private static DateTime Later => DateTime.UtcNow.AddDays(20);

    private readonly ReservationWorkspace workspace = new(fixture);

    [Fact]
    public async Task ALapsedHoldIsCancelledByNobodyAndSaysWhy()
    {
        var booked = await ABookedStayAsync();

        await workspace.LapseAsync(booked);

        var swept = await workspace.SweepAsync();

        Assert.True(swept.Expired >= 1);
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked));

        var history = await workspace.HistoryOfAsync(booked);

        Assert.Equal(2, history.Count);
        Assert.Null(history[^1].ChangedByUserId);
        Assert.Equal(TheHoldRanOut, history[^1].Reason);
    }

    [Fact]
    public async Task AHoldWhoseDeadlineIsStillAheadIsLeftAlone()
    {
        var booked = await ABookedStayAsync();

        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked));
        Assert.Single(await workspace.HistoryOfAsync(booked));
    }

    [Fact]
    public async Task ASecondPassLeavesWhatTheFirstOneMoved()
    {
        var booked = await ABookedStayAsync();

        await workspace.LapseAsync(booked);

        await workspace.SweepAsync();
        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked));
        Assert.Equal(2, (await workspace.HistoryOfAsync(booked)).Count);
    }

    [Fact]
    public async Task AStayWhoseCheckOutDayArrivedIsCompletedByNobody()
    {
        var booked = await AConfirmedStayAsync();

        await workspace.MoveTheStayAsync(booked, Today);

        var swept = await workspace.SweepAsync();

        Assert.True(swept.Completed >= 1);
        Assert.Equal(ReservationStatusCode.Completed, await workspace.StatusOfAsync(booked));

        var history = await workspace.HistoryOfAsync(booked);

        Assert.Equal(3, history.Count);
        Assert.Null(history[^1].ChangedByUserId);
        Assert.Null(history[^1].Reason);
    }

    [Fact]
    public async Task AStayThatIsStillRunningIsLeftAlone()
    {
        var booked = await AConfirmedStayAsync();

        await workspace.MoveTheStayAsync(booked, Today.AddDays(1));

        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(booked));
    }

    [Fact]
    public async Task ATermIsCompletedOnlyOnceItsDurationHasRun()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 2);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);

        await workspace.StartTheTermAsync(slot, TimeSpan.FromHours(1));
        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(booked.Id));

        await workspace.StartTheTermAsync(slot, TimeSpan.FromHours(3));
        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Completed, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task AHoldOverDatesThatPassedIsExpiredRatherThanCompleted()
    {
        var booked = await ABookedStayAsync();

        await workspace.MoveTheStayAsync(booked, Today.AddDays(-1));
        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked));

        await workspace.LapseAsync(booked);
        await workspace.SweepAsync();

        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked));
    }

    [Fact]
    public async Task OnePassMovesAHoldAndAFinishedBookingTogether()
    {
        var hold = await ABookedStayAsync();
        var finished = await AConfirmedStayAsync();

        await workspace.LapseAsync(hold);
        await workspace.MoveTheStayAsync(finished, Today);

        var swept = await workspace.SweepAsync();

        Assert.True(swept.Expired >= 1);
        Assert.True(swept.Completed >= 1);
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(hold));
        Assert.Equal(ReservationStatusCode.Completed, await workspace.StatusOfAsync(finished));
    }

    [Fact]
    public async Task OneBudgetIsSpentAcrossBothHalvesOfAPass()
    {
        // Whatever else is due goes first, so a budget of one lands here.
        await workspace.SweepAsync();

        var hold = await ABookedStayAsync();
        var finished = await AConfirmedStayAsync();

        await workspace.LapseAsync(hold);
        await workspace.MoveTheStayAsync(finished, Today);

        var first = await workspace.SweepAsync(batch: 1);

        Assert.Equal(1, first.Expired);
        Assert.Equal(0, first.Completed);
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(hold));
        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(finished));

        var second = await workspace.SweepAsync(batch: 1);

        Assert.Equal(1, second.Completed);
        Assert.Equal(ReservationStatusCode.Completed, await workspace.StatusOfAsync(finished));
    }

    [Fact]
    public async Task AReservationMovedUnderThePassIsCountedRatherThanRaised()
    {
        // Whatever else is due goes first, so the interceptor lands here.
        await workspace.SweepAsync();

        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.LapseAsync(booked.Id);

        var race = new RaceInterceptor(
            "UPDATE",
            () => workspace.CancelAsync(guest, RoleNames.Guest, booked.Id, "Plans changed"));

        var swept = await workspace.SweepAsync(interceptors: race);

        Assert.True(race.Fired);
        Assert.Equal(0, swept.Expired);
        Assert.Equal(1, swept.Skipped);
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked.Id));
        Assert.Equal("Plans changed", (await workspace.HistoryOfAsync(booked.Id))[^1].Reason);
    }

    private async Task<int> ABookedStayAsync()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        return (await workspace.BookStayAsync(guest, listing, Soon, nights: 2)).Id;
    }

    private async Task<int> AConfirmedStayAsync()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);

        return booked.Id;
    }
}
