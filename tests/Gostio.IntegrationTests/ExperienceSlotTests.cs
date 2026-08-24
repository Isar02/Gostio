using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ExperienceSlotTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-slot-owner";

    private const int ExperienceDuration = 120;

    private readonly ExperienceWorkspace workspace = new(fixture);

    [Fact]
    public async Task ASlotTakesItsDurationFromTheExperienceAndKeepsIt()
    {
        var (host, experience) = await AnExperienceAsync();

        var slot = await AddAsync(host, experience, In(days: 7));

        Assert.Equal(ExperienceDuration, slot.DurationMinutes);
        Assert.Equal(slot.StartTime.AddMinutes(ExperienceDuration), slot.EndTime);

        var lengthened = ExperienceRequests.Edit(
            await workspace.ReferencesAsync(), "A longer walk", durationMinutes: 300);

        await workspace.AsHostAsync(
            host,
            (IExperienceService experiences) =>
                experiences.UpdateAsync(experience, lengthened, default));

        var read = await AsHostAsync(host, slots => slots.GetAsync(experience, slot.Id, default));

        Assert.Equal(ExperienceDuration, read.DurationMinutes);
    }

    [Fact]
    public async Task AnEmptySlotHasEveryPlaceLeft()
    {
        var (host, experience) = await AnExperienceAsync();

        var slot = await AddAsync(host, experience, In(days: 7), capacity: 8);

        Assert.Equal(8, slot.Capacity);
        Assert.Equal(8, slot.RemainingCapacity);
    }

    [Fact]
    public async Task TheRemainingPlacesCountTheSeatsOfLiveReservationsOnly()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7), capacity: 10);

        await BookAsync(guest, slot.Id, seats: 2, ReservationStatusCode.Confirmed);
        await BookAsync(guest, slot.Id, seats: 1, ReservationStatusCode.Pending);
        await BookAsync(guest, slot.Id, seats: 3, ReservationStatusCode.Cancelled);
        await BookAsync(
            guest, slot.Id, seats: 4, ReservationStatusCode.Pending, expired: true);

        var read = await AsHostAsync(host, slots => slots.GetAsync(experience, slot.Id, default));

        Assert.Equal(10, read.Capacity);
        Assert.Equal(7, read.RemainingCapacity);
    }

    [Fact]
    public async Task TheRemainingPlacesReachTheListAsWellAsTheOneRow()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7), capacity: 6);

        await BookAsync(guest, slot.Id, seats: 4, ReservationStatusCode.Confirmed);

        var page = await AsHostAsync(
            host,
            slots => slots.SearchAsync(experience, new ExperienceSlotSearchRequest(), default));

        Assert.Equal(2, page.Items.Single().RemainingCapacity);
    }

    [Fact]
    public async Task TheCapacityCannotBeCutBelowWhatIsAlreadyBooked()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7), capacity: 10);

        await BookAsync(guest, slot.Id, seats: 5, ReservationStatusCode.Confirmed);

        var refused = await Assert.ThrowsAsync<BusinessException>(() => AsHostAsync(
            host, slots => slots.UpdateAsync(experience, slot.Id, Edit(capacity: 4), default)));

        Assert.Contains("below what is booked", refused.Message);

        var kept = await AsHostAsync(host, slots => slots.GetAsync(experience, slot.Id, default));

        Assert.Equal(10, kept.Capacity);

        var cut = await AsHostAsync(
            host, slots => slots.UpdateAsync(experience, slot.Id, Edit(capacity: 5), default));

        Assert.Equal(5, cut.Capacity);
        Assert.Equal(0, cut.RemainingCapacity);
    }

    [Fact]
    public async Task ClosingASlotLeavesItWhereItIs()
    {
        var (host, experience) = await AnExperienceAsync();

        var slot = await AddAsync(host, experience, In(days: 7));

        var closed = await AsHostAsync(
            host,
            slots => slots.UpdateAsync(
                experience, slot.Id, Edit(capacity: 8, isActive: false), default));

        Assert.False(closed.IsActive);

        var page = await AsHostAsync(
            host,
            slots => slots.SearchAsync(
                experience, new ExperienceSlotSearchRequest { IsActive = false }, default));

        Assert.Equal([slot.Id], page.Items.Select(item => item.Id));
    }

    // Closing a term is not the free action withdrawing a listing is: it ends
    // something people have paid for, which is a cancellation and owes them one.
    [Fact]
    public async Task ASlotWithABookingCannotBeClosed()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7));

        await BookAsync(guest, slot.Id, seats: 2, ReservationStatusCode.Confirmed);

        var refused = await Assert.ThrowsAsync<BusinessException>(() => AsHostAsync(
            host,
            slots => slots.UpdateAsync(
                experience, slot.Id, Edit(capacity: 8, isActive: false), default)));

        Assert.Contains("cancellation", refused.Message);

        var kept = await AsHostAsync(host, slots => slots.GetAsync(experience, slot.Id, default));

        Assert.True(kept.IsActive);
    }

    [Fact]
    public async Task ASlotWhoseOnlyBookingWasCancelledCanBeClosed()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7));

        await BookAsync(guest, slot.Id, seats: 2, ReservationStatusCode.Cancelled);

        var closed = await AsHostAsync(
            host,
            slots => slots.UpdateAsync(
                experience, slot.Id, Edit(capacity: 8, isActive: false), default));

        Assert.False(closed.IsActive);
    }

    // Two hours apart is a clash when the experience runs for two hours, and
    // exactly two hours apart is not: the end of a term is the start of what
    // may follow it.
    [Fact]
    public async Task ATermRunningIntoOneAlreadyThereIsRefused()
    {
        var (host, experience) = await AnExperienceAsync();

        var first = await AddAsync(host, experience, In(days: 7));

        await Assert.ThrowsAsync<BusinessException>(
            () => AddAsync(host, experience, first.StartTime.AddMinutes(60)));

        await Assert.ThrowsAsync<BusinessException>(
            () => AddAsync(host, experience, first.StartTime.AddMinutes(-60)));

        var next = await AddAsync(host, experience, first.EndTime);

        Assert.Equal(first.EndTime, next.StartTime);
    }

    [Fact]
    public async Task ATermThatHasAlreadyStartedIsRefused()
    {
        var (host, experience) = await AnExperienceAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, experience, DateTime.UtcNow.AddMinutes(-1)));

        Assert.Contains(nameof(ExperienceSlotCreateRequest.StartTime), refused.Errors.Keys);
    }

    [Fact]
    public async Task AWindowThatEndsBeforeItStartsIsRefused()
    {
        var (host, experience) = await AnExperienceAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsHostAsync(
            host,
            slots => slots.SearchAsync(
                experience,
                new ExperienceSlotSearchRequest
                {
                    From = In(days: 9),
                    To = In(days: 2),
                },
                default)));

        Assert.Contains(nameof(ExperienceSlotSearchRequest.To), refused.Errors.Keys);
    }

    [Fact]
    public async Task ASearchNarrowsToTheWindowItIsGiven()
    {
        var (host, experience) = await AnExperienceAsync();

        var soon = await AddAsync(host, experience, In(days: 2));

        await AddAsync(host, experience, In(days: 20));

        var page = await AsHostAsync(
            host,
            slots => slots.SearchAsync(
                experience,
                new ExperienceSlotSearchRequest { From = In(days: 1), To = In(days: 5) },
                default));

        Assert.Equal([soon.Id], page.Items.Select(item => item.Id));
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task AnAccountThatDoesNotOwnTheExperienceCannotWriteToItsSlots()
    {
        var (host, experience) = await AnExperienceAsync();
        var stranger = await fixture.AddUserAsync(Password, RoleNames.Host);

        var mine = await AddAsync(host, experience, In(days: 7));

        await Assert.ThrowsAsync<ForbiddenException>(
            () => AddAsync(stranger, experience, In(days: 9)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsHostAsync(
            stranger, slots => slots.UpdateAsync(experience, mine.Id, Edit(capacity: 2), default)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsHostAsync(
            stranger, slots => slots.DeleteAsync(experience, mine.Id, default)));
    }

    [Fact]
    public async Task AnAdministratorWritesToAnybodysSlots()
    {
        var (_, experience) = await AnExperienceAsync();
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);

        var added = await AsAsync(
            ListingWorkspace.Caller(administrator, RoleNames.Administrator),
            slots => slots.AddAsync(experience, Slot(In(days: 7), capacity: 8), default));

        Assert.Equal(8, added.RemainingCapacity);
    }

    [Fact]
    public async Task TheSlotsOfAWithdrawnExperienceAreOutOfReach()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7));

        await workspace.WithdrawAsync(host, experience);

        var browsing = ListingWorkspace.Caller(guest, RoleNames.Guest);

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            browsing,
            slots => slots.SearchAsync(experience, new ExperienceSlotSearchRequest(), default)));

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            browsing, slots => slots.GetAsync(experience, slot.Id, default)));
    }

    [Fact]
    public async Task ASlotWithABookingIsRefusedRatherThanDeleted()
    {
        var (host, experience) = await AnExperienceAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var slot = await AddAsync(host, experience, In(days: 7));

        await BookAsync(guest, slot.Id, seats: 2, ReservationStatusCode.Confirmed);

        var refused = await Assert.ThrowsAsync<BusinessException>(() => AsHostAsync(
            host, slots => slots.DeleteAsync(experience, slot.Id, default)));

        Assert.Contains("cannot be deleted", refused.Message);

        await using var check = fixture.CreateContext();

        Assert.True(await check.ExperienceSlots.AnyAsync(row => row.Id == slot.Id));
    }

    [Fact]
    public async Task ASlotNobodyBookedIsDeleted()
    {
        var (host, experience) = await AnExperienceAsync();

        var slot = await AddAsync(host, experience, In(days: 7));

        await AsHostAsync(host, slots => slots.DeleteAsync(experience, slot.Id, default));

        await using var check = fixture.CreateContext();

        Assert.False(await check.ExperienceSlots.AnyAsync(row => row.Id == slot.Id));
    }

    // Both callers are held at the lock and let go together. Without it they
    // each read a day with nothing on it and both put a term there, and the
    // experience ends up running twice at once.
    [Fact]
    public async Task TwoTermsThatClashArrivingAtOnceLeaveOnlyOne()
    {
        var (host, experience) = await AnExperienceAsync();

        var start = In(days: 7);
        var barrier = new CommandBarrier(callers: 2, "UPDLOCK");

        var landed = await Task.WhenAll(
            TryAddAsync(host, experience, start, barrier),
            TryAddAsync(host, experience, start.AddMinutes(60), barrier));

        Assert.Equal(2, barrier.Arrived);
        Assert.Single(landed, added => added);
        Assert.Single(await StoredAsync(experience));
    }

    private static DateTime In(int days) =>
        DateTime.UtcNow.AddDays(days).Date.AddHours(10);

    private static ExperienceSlotCreateRequest Slot(DateTime startTime, int capacity = 8) =>
        new() { StartTime = startTime, Capacity = capacity };

    private static ExperienceSlotUpdateRequest Edit(int capacity, bool isActive = true) =>
        new() { Capacity = capacity, IsActive = isActive };

    private async Task<(int Host, int Experience)> AnExperienceAsync() =>
        await workspace.AListingAsync(Password);

    private Task<ExperienceSlotResponse> AddAsync(
        int host,
        int experience,
        DateTime startTime,
        int capacity = 8) =>
        AsHostAsync(host, slots => slots.AddAsync(experience, Slot(startTime, capacity), default));

    private async Task<bool> TryAddAsync(
        int host,
        int experience,
        DateTime startTime,
        IInterceptor barrier)
    {
        try
        {
            await workspace.AsAsync(
                ListingWorkspace.Caller(host, RoleNames.Host),
                (IExperienceSlotService slots) =>
                    slots.AddAsync(experience, Slot(startTime), CancellationToken.None),
                barrier);

            return true;
        }
        catch (BusinessException)
        {
            return false;
        }
    }

    private async Task BookAsync(
        int guest,
        int slotId,
        int seats,
        ReservationStatusCode status,
        bool expired = false)
    {
        var now = DateTime.UtcNow;

        await using var db = fixture.CreateContext();

        db.Reservations.Add(new Reservation
        {
            UserId = guest,
            ExperienceSlotId = slotId,
            GuestCount = seats,
            ReservationStatusId = (int)status,
            ExpiresAt = expired ? now.AddMinutes(-30) : now.AddDays(1),
            PricePerPerson = 40m,
            TotalPrice = 40m * seats,
            CreatedAt = expired ? now.AddHours(-2) : now,
        });

        await db.SaveChangesAsync();
    }

    private async Task<IReadOnlyList<int>> StoredAsync(int experience)
    {
        await using var db = fixture.CreateContext();

        return await db.ExperienceSlots
            .Where(slot => slot.ExperienceId == experience)
            .Select(slot => slot.Id)
            .ToListAsync();
    }

    private Task<TResult> AsHostAsync<TResult>(
        int host,
        Func<IExperienceSlotService, Task<TResult>> work) =>
        workspace.AsHostAsync(host, work);

    private Task AsHostAsync(int host, Func<IExperienceSlotService, Task> work) =>
        workspace.AsHostAsync(host, work);

    private Task<TResult> AsAsync<TResult>(
        ICurrentUser caller,
        Func<IExperienceSlotService, Task<TResult>> work) =>
        workspace.AsAsync(caller, work);
}
