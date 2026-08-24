using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Authentication;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReservationTransitionTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-reservation-being-moved";

    private readonly ReservationWorkspace workspace = new(fixture);

    [Fact]
    public async Task ConfirmingAHoldMovesItAndRecordsWhoDidIt()
    {
        var reservation = await workspace.APendingStayAsync(Password);
        var actor = await fixture.AddUserAsync(Password, RoleNames.Host);

        await ChangeAsync(reservation, ReservationStatusCode.Confirmed, actor);

        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(reservation));

        var written = Assert.Single(await workspace.HistoryOfAsync(reservation));

        Assert.Equal((int)ReservationStatusCode.Pending, written.PreviousStatusId);
        Assert.Equal((int)ReservationStatusCode.Confirmed, written.NewStatusId);
        Assert.Equal(actor, written.ChangedByUserId);
        Assert.Null(written.Reason);
    }

    [Fact]
    public async Task ACancellationStoresItsTrimmedReasonAndNobodyWhenNobodyActed()
    {
        var reservation = await workspace.APendingStayAsync(Password);

        await ChangeAsync(
            reservation, ReservationStatusCode.Cancelled, null, "  The hold ran out  ");

        var written = Assert.Single(await workspace.HistoryOfAsync(reservation));

        Assert.Equal("The hold ran out", written.Reason);
        Assert.Null(written.ChangedByUserId);
    }

    [Fact]
    public async Task ACancellationWithoutAReasonChangesNothing()
    {
        var reservation = await workspace.APendingStayAsync(Password);

        await Assert.ThrowsAsync<ValidationException>(
            () => ChangeAsync(reservation, ReservationStatusCode.Cancelled, null));

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(reservation));
        Assert.Empty(await workspace.HistoryOfAsync(reservation));
    }

    [Fact]
    public async Task AMoveTheMachineRefusesChangesNothing()
    {
        var reservation = await workspace.APendingStayAsync(Password);

        await ChangeAsync(reservation, ReservationStatusCode.Cancelled, null, "Called off");

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => ChangeAsync(reservation, ReservationStatusCode.Cancelled, null));

        Assert.Contains("cannot become", refused.Message);
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(reservation));
        Assert.Single(await workspace.HistoryOfAsync(reservation));
    }

    [Fact]
    public async Task AHoldIsNeverCompletedWithoutBeingConfirmed()
    {
        var reservation = await workspace.APendingStayAsync(Password);

        await Assert.ThrowsAsync<BusinessException>(
            () => ChangeAsync(reservation, ReservationStatusCode.Completed, null));

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(reservation));
        Assert.Empty(await workspace.HistoryOfAsync(reservation));
    }

    [Fact]
    public async Task AReservationThatDoesNotExistIsNotFound() =>
        await Assert.ThrowsAsync<NotFoundException>(
            () => ChangeAsync(int.MaxValue, ReservationStatusCode.Cancelled, null));

    [Fact]
    public async Task TwoCallersMovingTheSameHoldLeaveOneMoveAndOneHistoryRow()
    {
        var reservation = await workspace.APendingStayAsync(Password);
        var barrier = new CommandBarrier(2, "UPDATE", "[Reservations]");

        var results = await Task.WhenAll(
            Attempt(reservation, ReservationStatusCode.Confirmed, barrier),
            Attempt(reservation, ReservationStatusCode.Confirmed, barrier));

        var loser = Assert.Single(results.OfType<BusinessException>());

        Assert.Contains("moved while", loser.Message);
        Assert.Equal(2, barrier.Arrived);
        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(reservation));
        Assert.Single(await workspace.HistoryOfAsync(reservation));
    }

    private async Task<Exception?> Attempt(
        int reservation,
        ReservationStatusCode to,
        params IInterceptor[] interceptors)
    {
        try
        {
            await ChangeAsync(reservation, to, null, interceptors: interceptors);

            return null;
        }
        catch (Exception failure)
        {
            return failure;
        }
    }

    private Task ChangeAsync(
        int reservation,
        ReservationStatusCode to,
        int? actor,
        string? reason = null,
        params IInterceptor[] interceptors) =>
        AsAsync(
            (IReservationTransitionService transitions) =>
                transitions.ChangeAsync(reservation, to, actor, reason, default),
            interceptors);

    private async Task AsAsync<TService>(Func<TService, Task> work, IInterceptor[] interceptors)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(new AnonymousUser(), interceptors);

        await work(services.GetRequiredService<TService>());
    }
}
