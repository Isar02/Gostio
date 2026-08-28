using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReservationCreationTests(DatabaseFixture fixture)
{
    private readonly ReservationWorkspace workspace = new(fixture);

    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task AStayIsHeldPendingAndOpensItsTrail()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 3);

        Assert.Equal(guest, booked.UserId);
        Assert.Equal((int)ReservationStatusCode.Pending, booked.ReservationStatusId);
        Assert.Equal(nameof(ReservationStatusCode.Pending), booked.Status);
        Assert.True(booked.ExpiresAt > booked.CreatedAt);

        var opening = Assert.Single(await workspace.HistoryOfAsync(booked.Id));

        Assert.Null(opening.PreviousStatusId);
        Assert.Equal((int)ReservationStatusCode.Pending, opening.NewStatusId);
        Assert.Equal(guest, opening.ChangedByUserId);
    }

    [Fact]
    public async Task AStayIsPricedByTheNightsItCoversPlusTheCleaningFee()
    {
        var (_, listing) = await workspace.AListingAsync(price: 100m);
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.BookStayAsync(guest, listing, Soon, nights: 3);

        Assert.Equal(300m, booked.AccommodationTotal);
        Assert.Equal(15m, booked.CleaningFee);
        Assert.Equal(315m, booked.TotalPrice);
        Assert.Null(booked.PricePerPerson);
    }

    [Fact]
    public async Task ARepricedRangeChargesItsOwnNightsAndLeavesTheRest()
    {
        var (host, listing) = await workspace.AListingAsync(price: 100m);
        var guest = await workspace.AGuestAsync();
        var checkIn = Soon;

        await workspace.RepriceAsync(host, listing, checkIn, checkIn.AddDays(1), 50m);

        var booked = await workspace.BookStayAsync(guest, listing, checkIn, nights: 3);

        Assert.Equal(200m, booked.AccommodationTotal);
        Assert.Equal(215m, booked.TotalPrice);
    }

    [Fact]
    public async Task ABlockedRangeRefusesTheDatesItTouches()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var checkIn = Soon;

        await workspace.CloseAsync(host, listing, checkIn.AddDays(2), checkIn.AddDays(4));

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookStayAsync(guest, listing, checkIn, nights: 3));

        Assert.Contains("closed", refused.Message);
    }

    [Fact]
    public async Task ARangeBlockingTheCheckOutDayAloneDoesNotRefuseTheStay()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var checkIn = Soon;

        await workspace.CloseAsync(host, listing, checkIn.AddDays(3), checkIn.AddDays(5));

        var booked = await workspace.BookStayAsync(guest, listing, checkIn, nights: 3);

        Assert.Equal(300m, booked.AccommodationTotal);
    }

    [Fact]
    public async Task DatesAnActiveReservationHoldsAreRefused()
    {
        var (_, listing) = await workspace.AListingAsync();
        var checkIn = Soon;

        await workspace.BookStayAsync(await workspace.AGuestAsync(), listing, checkIn, nights: 3);

        var later = await workspace.AGuestAsync();

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookStayAsync(later, listing, checkIn.AddDays(1), nights: 3));

        Assert.Contains("already booked", refused.Message);
    }

    [Fact]
    public async Task AStayBeginningOnTheDayAnotherEndsIsAllowed()
    {
        var (_, listing) = await workspace.AListingAsync();
        var checkIn = Soon;

        await workspace.BookStayAsync(await workspace.AGuestAsync(), listing, checkIn, nights: 3);

        var booked = await workspace.BookStayAsync(
            await workspace.AGuestAsync(), listing, checkIn.AddDays(3), nights: 2);

        Assert.Equal(200m, booked.AccommodationTotal);
    }

    [Fact]
    public async Task DatesACancelledReservationOnceHeldAreFreeAgain()
    {
        var (_, listing) = await workspace.AListingAsync();
        var checkIn = Soon;

        var first = await workspace.BookStayAsync(
            await workspace.AGuestAsync(), listing, checkIn, nights: 3);

        await workspace.CancelAsync(first.Id);

        var second = await workspace.BookStayAsync(
            await workspace.AGuestAsync(), listing, checkIn, nights: 3);

        Assert.NotEqual(first.Id, second.Id);
    }

    [Fact]
    public async Task AStayForMorePeopleThanThePlaceSleepsIsRefused()
    {
        var (_, listing) = await workspace.AListingAsync(maxGuests: 2);
        var guest = await workspace.AGuestAsync();

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookStayAsync(guest, listing, Soon, nights: 2, guestCount: 3));

        Assert.Contains("sleeps 2", refused.Message);
    }

    [Fact]
    public async Task AHostDoesNotBookTheirOwnListing()
    {
        var (host, listing) = await workspace.AListingAsync();

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookStayAsync(host, listing, Soon, nights: 2));
    }

    [Fact]
    public async Task AWithdrawnListingCannotBeBookedAndSaysNothingMore()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await new AccommodationWorkspace(fixture).WithdrawAsync(host, listing);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.BookStayAsync(guest, listing, Soon, nights: 2));
    }

    [Fact]
    public async Task AStayThatBeganYesterdayIsRefused()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookStayAsync(
            guest, listing, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-1)), nights: 2));
    }

    [Fact]
    public async Task AHoldNeverOutlivesTheStayItTakes()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var tomorrow = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(1));

        var booked = await workspace.BookStayAsync(guest, listing, tomorrow, nights: 2);

        Assert.True(booked.ExpiresAt <= StayTimes.BeginsAt(booked.CheckInDate!.Value));
    }

    [Fact]
    public async Task AStayForTheDayItIsBookedOnIsTakenUntilCheckIn()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var checkIn = new DateOnly(2027, 7, 15);

        var booked = await workspace.BookStayAtAsync(
            StayTimes.BeginsAt(checkIn).AddMinutes(-1), guest, listing, checkIn, nights: 2);

        Assert.Equal(checkIn, booked.CheckInDate);
        Assert.Equal(StayTimes.BeginsAt(checkIn), booked.ExpiresAt);
    }

    [Fact]
    public async Task AStayForTheDayItIsBookedOnIsRefusedOnceCheckInHasPassed()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var checkIn = new DateOnly(2027, 7, 15);

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookStayAtAsync(
            StayTimes.BeginsAt(checkIn), guest, listing, checkIn, nights: 2));
    }

    [Fact]
    public async Task AStayEndingBeforeItBeginsIsRefused()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookStayAsync(
            guest, listing, Soon, nights: 0));
    }

    [Fact]
    public async Task ARequestNamingNeitherSubjectIsRefused()
    {
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookAsync(
            guest, new ReservationCreateRequest { GuestCount = 2 }));
    }

    [Fact]
    public async Task ARequestSayingNothingAboutHowManyAreComingIsRefused()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookAsync(
            guest,
            new ReservationCreateRequest
            {
                AccommodationId = listing,
                CheckInDate = Soon,
                CheckOutDate = Soon.AddDays(2),
            }));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task ABookingForNobodyIsRefusedBeforeTheDatabaseSeesIt(int guestCount)
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookStayAsync(
            guest, listing, Soon, nights: 2, guestCount: guestCount));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task ATermBookedForNobodyIsRefusedTheSameWay(int guestCount)
    {
        var (_, slot) = await workspace.ATermAsync(4, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.BookTermAsync(guest, slot, guestCount));
    }

    [Fact]
    public async Task ARequestNamingBothSubjectsIsRefused()
    {
        var (_, listing) = await workspace.AListingAsync();
        var (_, slot) = await workspace.ATermAsync(4, DateTime.UtcNow.AddDays(10));

        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookAsync(
            guest,
            new ReservationCreateRequest
            {
                AccommodationId = listing,
                ExperienceSlotId = slot,
                CheckInDate = Soon,
                CheckOutDate = Soon.AddDays(2),
                GuestCount = 2,
            }));
    }

    [Fact]
    public async Task ATermIsHeldPendingAndPricedPerPerson()
    {
        var (_, slot) = await workspace.ATermAsync(6, DateTime.UtcNow.AddDays(10), price: 40m);
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 3);

        Assert.Equal(slot, booked.ExperienceSlotId);
        Assert.Null(booked.CheckInDate);
        Assert.Equal(40m, booked.PricePerPerson);
        Assert.Equal(120m, booked.TotalPrice);
        Assert.Null(booked.AccommodationTotal);
        Assert.Single(await workspace.HistoryOfAsync(booked.Id));
    }

    [Fact]
    public async Task ATermTakesBookingsUpToTheSeatsItHasLeft()
    {
        var (_, slot) = await workspace.ATermAsync(5, DateTime.UtcNow.AddDays(10));

        await workspace.BookTermAsync(await workspace.AGuestAsync(), slot, guestCount: 3);

        var booked = await workspace.BookTermAsync(
            await workspace.AGuestAsync(), slot, guestCount: 2);

        Assert.Equal(slot, booked.ExperienceSlotId);
    }

    [Fact]
    public async Task ATermRefusesTheBookingThatWouldPassItsCapacity()
    {
        var (_, slot) = await workspace.ATermAsync(5, DateTime.UtcNow.AddDays(10));

        await workspace.BookTermAsync(await workspace.AGuestAsync(), slot, guestCount: 3);

        var later = await workspace.AGuestAsync();

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookTermAsync(later, slot, guestCount: 3));

        Assert.Contains("2 left", refused.Message);
    }

    [Fact]
    public async Task AFullTermSaysSoRatherThanCountingToZero()
    {
        var (_, slot) = await workspace.ATermAsync(2, DateTime.UtcNow.AddDays(10));

        await workspace.BookTermAsync(await workspace.AGuestAsync(), slot, guestCount: 2);

        var later = await workspace.AGuestAsync();

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookTermAsync(later, slot, guestCount: 1));

        Assert.Contains("full", refused.Message);
    }

    [Fact]
    public async Task SeatsACancelledBookingHeldAreFreeAgain()
    {
        var (_, slot) = await workspace.ATermAsync(3, DateTime.UtcNow.AddDays(10));

        var first = await workspace.BookTermAsync(
            await workspace.AGuestAsync(), slot, guestCount: 3);

        await workspace.CancelAsync(first.Id);

        var second = await workspace.BookTermAsync(
            await workspace.AGuestAsync(), slot, guestCount: 3);

        Assert.NotEqual(first.Id, second.Id);
    }

    [Fact]
    public async Task AGuestHoldingATermIsRefusedASecondBookingOnIt()
    {
        var (_, slot) = await workspace.ATermAsync(6, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.AGuestAsync();

        await workspace.BookTermAsync(guest, slot, guestCount: 1);

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => workspace.BookTermAsync(guest, slot, guestCount: 1));

        Assert.Contains("already hold a place", refused.Message);
    }

    [Fact]
    public async Task ATermTheGuestCalledOffIsOpenToThemAgain()
    {
        var (_, slot) = await workspace.ATermAsync(6, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.AGuestAsync();

        var first = await workspace.BookTermAsync(guest, slot, guestCount: 1);

        await workspace.CancelAsync(first.Id);

        var second = await workspace.BookTermAsync(guest, slot, guestCount: 1);

        Assert.NotEqual(first.Id, second.Id);
    }

    [Fact]
    public async Task ATermAGuestLetLapseIsOpenToThemAgain()
    {
        var (_, slot) = await workspace.ATermAsync(6, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.AGuestAsync();

        var first = await workspace.BookTermAsync(guest, slot, guestCount: 1);

        await workspace.LapseAsync(first.Id);

        var second = await workspace.BookTermAsync(guest, slot, guestCount: 1);

        Assert.NotEqual(first.Id, second.Id);
    }

    // Both taps are held until each has reached the lock, so the one that loses
    // the race asks its question after the other has written its booking. That
    // is what proves the guard sits inside the lock rather than in front of it.
    [Fact]
    public async Task ATermBookedTwiceAtOnceByOneGuestLeavesOneBooking()
    {
        var (_, slot) = await workspace.ATermAsync(6, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.AGuestAsync();
        var barrier = new CommandBarrier(2, "UPDLOCK", "[Experiences]");

        var results = await Task.WhenAll(
            Attempt(() => workspace.BookTermAsync(guest, slot, guestCount: 1, barrier)),
            Attempt(() => workspace.BookTermAsync(guest, slot, guestCount: 1, barrier)));

        Assert.Equal(2, barrier.Arrived);
        Assert.Single(results, failure => failure is null);

        var refused = Assert.Single(results.OfType<BusinessException>());

        Assert.Contains("already hold a place", refused.Message);
    }

    [Fact]
    public async Task ATermCarryingDatesOfItsOwnIsRefused()
    {
        var (_, slot) = await workspace.ATermAsync(4, DateTime.UtcNow.AddDays(10));

        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(() => workspace.BookAsync(
            guest,
            new ReservationCreateRequest
            {
                ExperienceSlotId = slot,
                CheckInDate = Soon,
                CheckOutDate = Soon.AddDays(2),
                GuestCount = 2,
            }));
    }

    [Fact]
    public async Task ATermThatDoesNotExistIsNotFound()
    {
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.BookTermAsync(guest, int.MaxValue, guestCount: 1));
    }

    [Fact]
    public async Task TwoGuestsTakingTheLastSeatLeaveOneBooking()
    {
        var (_, slot) = await workspace.ATermAsync(1, DateTime.UtcNow.AddDays(10));
        var first = await workspace.AGuestAsync();
        var second = await workspace.AGuestAsync();

        var results = await Task.WhenAll(
            Attempt(() => workspace.BookTermAsync(first, slot, guestCount: 1)),
            Attempt(() => workspace.BookTermAsync(second, slot, guestCount: 1)));

        Assert.Single(results, failure => failure is null);
        Assert.Single(results.OfType<BusinessException>());
    }

    [Fact]
    public async Task TwoGuestsClaimingTheSameNightsLeaveOneBooking()
    {
        var (_, listing) = await workspace.AListingAsync();
        var first = await workspace.AGuestAsync();
        var second = await workspace.AGuestAsync();
        var checkIn = Soon;

        var results = await Task.WhenAll(
            Attempt(() => workspace.BookStayAsync(first, listing, checkIn, nights: 3)),
            Attempt(() => workspace.BookStayAsync(second, listing, checkIn.AddDays(1), nights: 3)));

        Assert.Single(results, failure => failure is null);
        Assert.Single(results.OfType<BusinessException>());
    }

    [Fact]
    public async Task ABookingAndADeleteOfTheSameTermQueueRatherThanCollide()
    {
        var (host, slot) = await workspace.ATermAsync(4, DateTime.UtcNow.AddDays(10));
        var guest = await workspace.AGuestAsync();
        var barrier = new CommandBarrier(2, "UPDLOCK", "[Experiences]");

        var results = await Task.WhenAll(
            Attempt(() => workspace.BookTermAsync(guest, slot, guestCount: 1, barrier)),
            Attempt(() => workspace.DeleteTermAsync(host, slot, barrier)));

        Assert.Equal(2, barrier.Arrived);
        Assert.DoesNotContain(results, failure => failure is DbUpdateException);

        var refused = results.First(failure => failure is not null);

        Assert.True(
            refused is NotFoundException or BusinessException,
            $"neither side should have failed this way: {refused}");
    }

    [Fact]
    public async Task ATermThatStartsWhileTheBookingWaitsForTheLockIsRefused()
    {
        var startsAt = DateTime.UtcNow.AddSeconds(3);
        var (_, slot) = await workspace.ATermAsync(4, startsAt);
        var guest = await workspace.AGuestAsync();

        await using var holder = fixture.CreateContext();
        await using var held = await holder.Database.BeginTransactionAsync();

        await holder.Database.ExecuteSqlAsync(
            $"""
            SELECT TOP 1 1 FROM [Experiences] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Id] = {await workspace.ExperienceOfAsync(slot)}
            """);

        var booking = Attempt(() => workspace.BookTermAsync(guest, slot, guestCount: 1));

        while (DateTime.UtcNow <= startsAt)
        {
            await Task.Delay(100);
        }

        await held.RollbackAsync();

        var refused = await booking;

        Assert.IsType<BusinessException>(refused);
        Assert.Contains("already started", refused.Message);
    }

    private static async Task<Exception?> Attempt(Func<Task> booking)
    {
        try
        {
            await booking();

            return null;
        }
        catch (Exception failure)
        {
            return failure;
        }
    }
}
