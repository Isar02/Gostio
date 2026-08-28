using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReservationMoveTests(DatabaseFixture fixture)
{
    private readonly ReservationWorkspace workspace = new(fixture);

    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    private static DateTime Later => DateTime.UtcNow.AddDays(10);

    [Fact]
    public async Task TheGuestTheHostAndAnAdministratorAllReachOne()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();

        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        Assert.Equal(booked.Id, (await workspace.ReadAsync(guest, RoleNames.Guest, booked.Id)).Id);
        Assert.Equal(booked.Id, (await workspace.ReadAsync(host, RoleNames.Host, booked.Id)).Id);
        Assert.Equal(
            booked.Id,
            (await workspace.ReadAsync(administrator, RoleNames.Administrator, booked.Id)).Id);
    }

    [Fact]
    public async Task ToAnybodyElseItDoesNotExist()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var stranger = await workspace.AGuestAsync();

        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stranger, RoleNames.Guest, booked.Id));
    }

    [Fact]
    public async Task AReservationThatDoesNotExistIsNotFound()
    {
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(guest, RoleNames.Guest, int.MaxValue));
    }

    // A stranger is told the same thing whether the id is real or not, and the
    // moves answer as the read does rather than owning up to a 403.
    [Fact]
    public async Task AStrangerMovingOneIsToldItDoesNotExistEither()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var stranger = await workspace.AGuestAsync();

        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ConfirmAsync(stranger, RoleNames.Host, booked.Id));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.CancelAsync(stranger, RoleNames.Guest, booked.Id, "Not mine"));

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task TheHostConfirmsAHoldAndTheTrailNamesThem()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        var confirmed = await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);

        Assert.Equal(nameof(ReservationStatusCode.Confirmed), confirmed.Status);

        var trail = await workspace.HistoryOfAsync(booked.Id);

        Assert.Equal(2, trail.Count);
        Assert.Equal((int)ReservationStatusCode.Pending, trail[^1].PreviousStatusId);
        Assert.Equal((int)ReservationStatusCode.Confirmed, trail[^1].NewStatusId);
        Assert.Equal(host, trail[^1].ChangedByUserId);
        Assert.Null(trail[^1].Reason);
    }

    [Fact]
    public async Task AnAdministratorConfirmsAHoldOnAnybodysListing()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.ConfirmAsync(administrator, RoleNames.Administrator, booked.Id);

        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task TheGuestDoesNotConfirmTheirOwnBooking()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.ConfirmAsync(guest, RoleNames.Guest, booked.Id));

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task ConfirmingWhatIsAlreadyConfirmedIsRefused()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id));

        Assert.Contains("cannot become", refused.Message);
        Assert.Equal(2, (await workspace.HistoryOfAsync(booked.Id)).Count);
    }

    [Fact]
    public async Task AHoldThatLapsedIsConfirmedWhenNobodyTookItsNights()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.LapseAsync(booked.Id);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);

        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(booked.Id));
    }

    // The seats it holds are its own, so a count that kept them would refuse
    // every confirmation of a term booked to the last place.
    [Fact]
    public async Task AHoldNeverStandsInItsOwnWay()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 2, startsAt: Later);
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 2);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);

        Assert.Equal(ReservationStatusCode.Confirmed, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task NightsTakenWhileTheHoldWasDownRefuseTheConfirmation()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.LapseAsync(booked.Id);
        await workspace.BookStayAsync(somebodyElse, listing, Soon, nights: 2);

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id));

        Assert.Contains("taken while", refused.Message);
        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task ATermThatRanOutWhileTheHoldWasDownRefusesTheConfirmation()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 3, startsAt: Later);
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();
        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 2);

        await workspace.LapseAsync(booked.Id);
        await workspace.BookTermAsync(somebodyElse, slot, guestCount: 2);

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id));

        Assert.Contains("ran out of room", refused.Message);
        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task ATermTheGuestBookedAgainWhileTheHoldWasDownRefusesTheConfirmation()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 6, startsAt: Later);
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 1);

        await workspace.LapseAsync(booked.Id);
        await workspace.BookTermAsync(guest, slot, guestCount: 1);

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id));

        Assert.Contains("booked this term again", refused.Message);
        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task DatesClosedAfterTheBookingRefuseTheConfirmation()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.CloseAsync(host, listing, Soon, Soon.AddDays(1));

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id));

        Assert.Contains("closed", refused.Message);
    }

    [Fact]
    public async Task TheGuestCancelsWithAReasonAndTheTrailKeepsIt()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        var cancelled = await workspace.CancelAsync(
            guest, RoleNames.Guest, booked.Id, "  Plans changed  ");

        Assert.Equal(nameof(ReservationStatusCode.Cancelled), cancelled.Status);

        var trail = await workspace.HistoryOfAsync(booked.Id);

        Assert.Equal("Plans changed", trail[^1].Reason);
        Assert.Equal(guest, trail[^1].ChangedByUserId);
    }

    [Fact]
    public async Task TheHostTurnsAHoldDownWithAReasonOfTheirOwn()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.CancelAsync(host, RoleNames.Host, booked.Id, "The place is being repaired");

        var trail = await workspace.HistoryOfAsync(booked.Id);

        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked.Id));
        Assert.Equal("The place is being repaired", trail[^1].Reason);
        Assert.Equal(host, trail[^1].ChangedByUserId);
    }

    [Fact]
    public async Task AConfirmedStayIsStillTheGuestsToCancel()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);
        await workspace.CancelAsync(guest, RoleNames.Guest, booked.Id, "Something came up");

        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked.Id));
        Assert.Equal(3, (await workspace.HistoryOfAsync(booked.Id)).Count);
    }

    [Fact]
    public async Task ACancellationWithoutAReasonChangesNothing()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.CancelAsync(guest, RoleNames.Guest, booked.Id, "   "));

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
        Assert.Single(await workspace.HistoryOfAsync(booked.Id));
    }

    // The move is attempted before the place is checked, so a reservation that
    // moved is reported as that rather than as a place that has gone.
    [Fact]
    public async Task AMoveTheMachineRefusesIsNamedAsThatWhateverElseIsWrong()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.CancelAsync(guest, RoleNames.Guest, booked.Id, "Plans changed");
        await workspace.BookStayAsync(somebodyElse, listing, Soon, nights: 2);

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id));

        Assert.Contains("cannot become", refused.Message);
    }

    [Fact]
    public async Task AReservationCancelledWhileTheConfirmationWaitsIsReportedAsMoved()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        var race = new RaceInterceptor("UPDLOCK", async () =>
        {
            await workspace.CancelAsync(guest, RoleNames.Guest, booked.Id, "Plans changed");
            await workspace.BookStayAsync(somebodyElse, listing, Soon, nights: 2);
        });

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id, race));

        Assert.True(race.Fired);
        Assert.Contains("moved while", refused.Message);
    }

    [Fact]
    public async Task AConfirmationAndABookingRacingForTheSameNightsLeaveOneWinner()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.LapseAsync(booked.Id);

        var barrier = new CommandBarrier(2, "UPDLOCK", "[Accommodations]");

        var results = await Task.WhenAll(
            Attempt(() => workspace.ConfirmAsync(host, RoleNames.Host, booked.Id, barrier)),
            Attempt(() => workspace.BookAsync(
                somebodyElse,
                new ReservationCreateRequest
                {
                    AccommodationId = listing,
                    CheckInDate = Soon,
                    CheckOutDate = Soon.AddDays(2),
                    GuestCount = 2,
                },
                barrier)));

        Assert.Equal(2, barrier.Arrived);
        Assert.Single(results.OfType<BusinessException>());
        Assert.Contains(results, failure => failure is null);
    }

    private static async Task<Exception?> Attempt(Func<Task> work)
    {
        try
        {
            await work();

            return null;
        }
        catch (Exception failure)
        {
            return failure;
        }
    }
}
