using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class AccommodationAvailabilityTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-calendar-owner";

    private static DateOnly Day(int offset) =>
        DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(offset);

    [Fact]
    public async Task ABlockedRangeIsStoredAndNeedsNoPrice()
    {
        var (host, listing) = await AListingAsync();

        var blocked = await AddAsync(host, listing, Blocked(10, 14));

        Assert.Equal(Day(10), blocked.StartDate);
        Assert.Equal(Day(14), blocked.EndDate);
        Assert.False(blocked.IsAvailable);
        Assert.Null(blocked.PriceOverride);
    }

    // The calendar is already open, so a range that leaves it open and says
    // nothing else would mean nothing at all.
    [Fact]
    public async Task AnOpenRangeWithoutAPriceIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, Open(10, 14, price: null)));

        Assert.Contains(
            nameof(AccommodationAvailabilityRequest.PriceOverride), refused.Errors.Keys);
    }

    [Fact]
    public async Task AnOpenRangeCarryingAPriceIsStored()
    {
        var (host, listing) = await AListingAsync();

        var priced = await AddAsync(host, listing, Open(10, 14, price: 140m));

        Assert.True(priced.IsAvailable);
        Assert.Equal(140m, priced.PriceOverride);
    }

    // The constraint is not a strict either-or: closing the dates does not stop
    // a host recording what the nights would have cost.
    [Fact]
    public async Task ABlockedRangeMayKeepAPriceOfItsOwn()
    {
        var (host, listing) = await AListingAsync();

        var blocked = await AddAsync(
            host,
            listing,
            new()
            {
                StartDate = Day(10),
                EndDate = Day(14),
                IsAvailable = false,
                PriceOverride = 140m,
            });

        Assert.False(blocked.IsAvailable);
        Assert.Equal(140m, blocked.PriceOverride);
    }

    [Fact]
    public async Task ASingleDayRangeIsAllowed()
    {
        var (host, listing) = await AListingAsync();

        var oneDay = await AddAsync(host, listing, Blocked(10, 10));

        Assert.Equal(oneDay.StartDate, oneDay.EndDate);
    }

    [Fact]
    public async Task ARangeThatEndsBeforeItStartsIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, Blocked(14, 10)));

        Assert.Contains(nameof(AccommodationAvailabilityRequest.EndDate), refused.Errors.Keys);
    }

    [Fact]
    public async Task ARangeThatDoesNotSayWhetherItIsOpenIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AddAsync(
            host, listing, new() { StartDate = Day(10), EndDate = Day(14) }));

        Assert.Contains(nameof(AccommodationAvailabilityRequest.IsAvailable), refused.Errors.Keys);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    public async Task APriceThatIsNotAboveZeroIsRefused(decimal price)
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, Open(10, 14, price)));

        Assert.Contains(
            nameof(AccommodationAvailabilityRequest.PriceOverride), refused.Errors.Keys);
    }

    // Both dates are inclusive, so two ranges sharing a single day are two
    // answers for that day.
    [Theory]
    [InlineData(12, 20)]
    [InlineData(5, 10)]
    [InlineData(11, 13)]
    [InlineData(5, 20)]
    [InlineData(10, 14)]
    public async Task ARangeOverlappingOneAlreadyThereIsRefused(int start, int end)
    {
        var (host, listing) = await AListingAsync();

        await AddAsync(host, listing, Blocked(10, 14));

        await Assert.ThrowsAsync<BusinessException>(
            () => AddAsync(host, listing, Blocked(start, end)));

        Assert.Single(await StoredAsync(listing));
    }

    [Fact]
    public async Task ARangeEndingTheDayBeforeTheNextBeginsIsFine()
    {
        var (host, listing) = await AListingAsync();

        await AddAsync(host, listing, Blocked(10, 14));
        await AddAsync(host, listing, Blocked(15, 20));

        Assert.Equal(2, (await StoredAsync(listing)).Count);
    }

    [Fact]
    public async Task TheSameDatesAreFreeAgainOnceTheRangeIsRemoved()
    {
        var (host, listing) = await AListingAsync();

        var blocked = await AddAsync(host, listing, Blocked(10, 14));

        await AsHostAsync(host, ranges => ranges.DeleteAsync(listing, blocked.Id, default));

        Assert.Empty(await StoredAsync(listing));

        await AddAsync(host, listing, Open(10, 14, price: 140m));

        Assert.Single(await StoredAsync(listing));
    }

    [Fact]
    public async Task RemovingARangeThatIsNotThereIsRefused()
    {
        var (host, listing) = await AListingAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => AsHostAsync(
            host, ranges => ranges.DeleteAsync(listing, int.MaxValue, default)));
    }

    // A range belongs to one listing, so its id is not a way into another one.
    [Fact]
    public async Task ARangeCannotBeReachedThroughAListingItDoesNotBelongTo()
    {
        var (host, listing) = await AListingAsync();
        var (other, otherListing) = await AListingAsync();

        var blocked = await AddAsync(host, listing, Blocked(10, 14));

        await Assert.ThrowsAsync<NotFoundException>(() => AsHostAsync(
            other, ranges => ranges.GetAsync(otherListing, blocked.Id, default)));
    }

    [Fact]
    public async Task AnAccountThatDoesNotOwnTheListingCannotWriteItsCalendar()
    {
        var (host, listing) = await AListingAsync();
        var stranger = await fixture.AddUserAsync(Password, RoleNames.Host);

        var blocked = await AddAsync(host, listing, Blocked(10, 14));

        await Assert.ThrowsAsync<ForbiddenException>(
            () => AddAsync(stranger, listing, Blocked(20, 24)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsHostAsync(
            stranger, ranges => ranges.DeleteAsync(listing, blocked.Id, default)));
    }

    [Fact]
    public async Task AnAdministratorWritesAnybodysCalendar()
    {
        var (_, listing) = await AListingAsync();
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);

        var blocked = await AsAsync(
            Caller(administrator, RoleNames.Administrator),
            ranges => ranges.AddAsync(listing, Blocked(10, 14), default));

        Assert.False(blocked.IsAvailable);
    }

    [Fact]
    public async Task TheCalendarOfAWithdrawnListingIsOutOfReach()
    {
        var (host, listing) = await AListingAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        await AddAsync(host, listing, Blocked(10, 14));
        await WithdrawAsync(host, listing);

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            Caller(guest, RoleNames.Guest),
            ranges => ranges.SearchAsync(listing, new(), default)));
    }

    // A block that closes a stay usually starts before the dates being asked
    // about, so a window wants every range it touches rather than only the ones
    // it contains.
    [Fact]
    public async Task TheSearchReturnsEveryRangeTheWindowTouches()
    {
        var (host, listing) = await AListingAsync();

        await AddAsync(host, listing, Blocked(1, 5));
        var straddling = await AddAsync(host, listing, Blocked(9, 12));
        var inside = await AddAsync(host, listing, Blocked(14, 16));
        await AddAsync(host, listing, Blocked(30, 34));

        var found = await AsHostAsync(host, ranges => ranges.SearchAsync(
            listing, new() { From = Day(10), To = Day(20) }, default));

        Assert.Equal(
            [straddling.Id, inside.Id], found.Items.Select(range => range.Id));
    }

    [Fact]
    public async Task TheSearchCanAskForOnlyTheBlockedRanges()
    {
        var (host, listing) = await AListingAsync();

        var blocked = await AddAsync(host, listing, Blocked(10, 14));

        await AddAsync(host, listing, Open(20, 24, price: 140m));

        var found = await AsHostAsync(host, ranges => ranges.SearchAsync(
            listing, new() { IsAvailable = false }, default));

        Assert.Equal([blocked.Id], found.Items.Select(range => range.Id));
    }

    [Fact]
    public async Task TheRangesComeBackInDateOrder()
    {
        var (host, listing) = await AListingAsync();

        var later = await AddAsync(host, listing, Blocked(20, 24));
        var earlier = await AddAsync(host, listing, Blocked(10, 14));

        var found = await AsHostAsync(
            host, ranges => ranges.SearchAsync(listing, new(), default));

        Assert.Equal([earlier.Id, later.Id], found.Items.Select(range => range.Id));
    }

    // Both callers are held at the lock and let go together, so they contend on
    // purpose rather than by luck. Without it they each find the calendar clear
    // and both ranges land on the same dates.
    [Fact]
    public async Task TwoOverlappingRangesAtOnceLeaveOnlyOne()
    {
        var (host, listing) = await AListingAsync();

        var barrier = new CommandBarrier(callers: 2, "UPDLOCK");

        var landed = await Task.WhenAll(
            TryAddAsync(host, listing, Blocked(10, 14), barrier),
            TryAddAsync(host, listing, Blocked(12, 16), barrier));

        Assert.Equal(2, barrier.Arrived);
        Assert.Single(landed, added => added);
        Assert.Single(await StoredAsync(listing));
    }

    private static AccommodationAvailabilityRequest Blocked(int start, int end) =>
        new() { StartDate = Day(start), EndDate = Day(end), IsAvailable = false };

    private static AccommodationAvailabilityRequest Open(int start, int end, decimal? price) =>
        new()
        {
            StartDate = Day(start),
            EndDate = Day(end),
            IsAvailable = true,
            PriceOverride = price,
        };

    private static ICurrentUser Caller(int userId, params string[] roles) =>
        new SignedInUser(userId, roles);

    private Task<AccommodationAvailabilityResponse> AddAsync(
        int host,
        int listing,
        AccommodationAvailabilityRequest request) =>
        AsHostAsync(host, ranges => ranges.AddAsync(listing, request, default));

    private async Task<bool> TryAddAsync(
        int host,
        int listing,
        AccommodationAvailabilityRequest request,
        IInterceptor barrier)
    {
        await using var services = fixture.BuildServices(Caller(host, RoleNames.Host), barrier);

        try
        {
            await services.GetRequiredService<IAccommodationAvailabilityService>()
                .AddAsync(listing, request, CancellationToken.None);

            return true;
        }
        catch (BusinessException)
        {
            return false;
        }
    }

    private async Task<IReadOnlyList<int>> StoredAsync(int listing)
    {
        await using var db = fixture.CreateContext();

        return await db.AccommodationAvailability
            .Where(range => range.AccommodationId == listing)
            .Select(range => range.Id)
            .ToListAsync();
    }

    private async Task<ListingReferences> ReferencesAsync() =>
        new(
            await fixture.EnsureCityAsync("Sarajevo"),
            await fixture.EnsureAccommodationTypeAsync("Apartment"),
            await fixture.EnsureAccommodationCategoryAsync("City break"));

    private async Task<(int Host, int Listing)> AListingAsync()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, $"A listing {Guid.NewGuid():N}"), default),
            services => services.GetRequiredService<IAccommodationService>());

        return (host, created.Id);
    }

    private async Task WithdrawAsync(int host, int listing)
    {
        var withdrawn = ListingRequests.Edit(
            await ReferencesAsync(), "Taken off the market", isActive: false);

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.UpdateAsync(listing, withdrawn, default),
            services => services.GetRequiredService<IAccommodationService>());
    }

    private Task<TResult> AsHostAsync<TResult>(
        int host,
        Func<IAccommodationAvailabilityService, Task<TResult>> work) =>
        AsAsync(Caller(host, RoleNames.Host), work);

    private Task AsHostAsync(int host, Func<IAccommodationAvailabilityService, Task> work) =>
        AsHostAsync(host, async ranges =>
        {
            await work(ranges);

            return true;
        });

    private async Task<TResult> AsAsync<TResult>(
        ICurrentUser caller,
        Func<IAccommodationAvailabilityService, Task<TResult>> work) =>
        await AsAsync(
            caller,
            work,
            services => services.GetRequiredService<IAccommodationAvailabilityService>());

    private async Task<TResult> AsAsync<TService, TResult>(
        ICurrentUser caller,
        Func<TService, Task<TResult>> work,
        Func<IServiceProvider, TService> resolve)
    {
        await using var services = fixture.BuildServices(caller);

        return await work(resolve(services));
    }
}
