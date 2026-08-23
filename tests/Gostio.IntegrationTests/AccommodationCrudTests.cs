using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class AccommodationCrudTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-listing-owner";

    [Fact]
    public async Task AHostKeepsTheListingTheyCreate()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "  A loft over the river  "),
                CancellationToken.None));

        Assert.Equal(host, created.HostId);
        Assert.True(created.IsActive);
        Assert.Equal("A loft over the river", created.Title);
        Assert.Equal("Sarajevo", created.CityName);
        Assert.Equal("Bosnia and Herzegovina", created.CountryName);
    }

    [Fact]
    public async Task AnAdministratorCreatesAListingForANamedHost()
    {
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(administrator, RoleNames.Administrator),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A stone house", hostId: host),
                CancellationToken.None));

        Assert.Equal(host, created.HostId);
    }

    // The controller keeps a guest away from the endpoint; this is the same
    // answer given one layer further in, where the role is a fact about the row.
    [Fact]
    public async Task AnAccountThatHostsNothingCannotKeepAListing()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var references = await ReferencesAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAsync(
            Caller(guest, RoleNames.Guest),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A room a guest cannot let"),
                CancellationToken.None)));

        Assert.Contains(nameof(AccommodationCreateRequest.HostId), refused.Errors.Keys);
    }

    [Fact]
    public async Task AHostMayNotPutAListingOnSomebodyElse()
    {
        var mine = await fixture.AddUserAsync(Password, RoleNames.Host);
        var theirs = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(mine, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "Not mine to give", hostId: theirs),
                CancellationToken.None)));
    }

    [Fact]
    public async Task AReferenceNothingHasIsRefusedUnderItsOwnField()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        await RefusedUnderAsync(
            host,
            references with { CityId = int.MaxValue },
            nameof(AccommodationCreateRequest.CityId));

        await RefusedUnderAsync(
            host,
            references with { TypeId = int.MaxValue },
            nameof(AccommodationCreateRequest.AccommodationTypeId));

        await RefusedUnderAsync(
            host,
            references with { CategoryId = int.MaxValue },
            nameof(AccommodationCreateRequest.AccommodationCategoryId));
    }

    [Fact]
    public async Task AHostEditsTheirOwnListingAndNobodyElses()
    {
        var mine = await fixture.AddUserAsync(Password, RoleNames.Host);
        var theirs = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(mine, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A flat by the market"), CancellationToken.None));

        var saved = await AsAsync(
            Caller(mine, RoleNames.Host),
            listings => listings.UpdateAsync(
                created.Id,
                ListingRequests.Edit(references, "A quieter flat by the market", price: 140m),
                CancellationToken.None));

        Assert.Equal("A quieter flat by the market", saved.Title);
        Assert.Equal(140m, saved.PricePerNight);

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(theirs, RoleNames.Host),
            listings => listings.UpdateAsync(
                created.Id,
                ListingRequests.Edit(references, "Taken over"),
                CancellationToken.None)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(theirs, RoleNames.Host),
            listings => listings.DeleteAsync(created.Id, CancellationToken.None)));
    }

    [Fact]
    public async Task AnAdministratorEditsAnybodysListing()
    {
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A cottage by the lake"), CancellationToken.None));

        var saved = await AsAsync(
            Caller(administrator, RoleNames.Administrator),
            listings => listings.UpdateAsync(
                created.Id,
                ListingRequests.Edit(references, "A cottage by the lake", isActive: false),
                CancellationToken.None));

        Assert.False(saved.IsActive);
        Assert.Equal(host, saved.HostId);
    }

    // A withdrawn listing is off the market, not gone: the host still manages it
    // and an administrator still sees it, while nobody else can reach it at all.
    [Fact]
    public async Task AWithdrawnListingLeavesTheBrowseListButNotItsOwners()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var references = await ReferencesAsync();

        var open = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "Still on the market"), CancellationToken.None));

        var withdrawn = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "Taken off the market"), CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.UpdateAsync(
                withdrawn.Id,
                ListingRequests.Edit(references, "Taken off the market", isActive: false),
                CancellationToken.None));

        Assert.Equal([open.Id], await BrowsedByAsync(Caller(guest, RoleNames.Guest), host));

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            Caller(guest, RoleNames.Guest),
            listings => listings.GetAsync(withdrawn.Id, CancellationToken.None)));

        Assert.Equal(
            [open.Id, withdrawn.Id],
            (await BrowsedByAsync(Caller(host, RoleNames.Host), host)).Order());

        Assert.Equal(
            [open.Id, withdrawn.Id],
            (await BrowsedByAsync(Caller(administrator, RoleNames.Administrator), host)).Order());
    }

    [Fact]
    public async Task ASearchNarrowsByCityPriceAndCapacity()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var here = await ReferencesAsync();
        var elsewhere = here with { CityId = await fixture.EnsureCityAsync("Mostar") };

        var wanted = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(here, "Four beds at ninety", price: 90m, maxGuests: 4),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(here, "Four beds at three hundred", price: 300m, maxGuests: 4),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(here, "Two beds at ninety", price: 90m, maxGuests: 2),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(
                    elsewhere, "Four beds at ninety, elsewhere", price: 90m, maxGuests: 4),
                CancellationToken.None));

        var page = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.SearchAsync(
                new AccommodationSearchRequest
                {
                    HostId = host,
                    CityId = here.CityId,
                    MaxPrice = 100m,
                    MinGuests = 4,
                },
                CancellationToken.None));

        Assert.Equal([wanted.Id], page.Items.Select(item => item.Id));
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task ASearchNarrowsByTitle()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var wanted = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "An attic with a skylight"),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A basement with no window"),
                CancellationToken.None));

        var page = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.SearchAsync(
                new AccommodationSearchRequest { HostId = host, Title = "skylight" },
                CancellationToken.None));

        Assert.Equal([wanted.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task ADeletedListingTakesItsPhotosAndAvailabilityWithIt()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A studio nobody booked"), CancellationToken.None));

        await using (var db = fixture.CreateContext())
        {
            db.AccommodationPhotos.Add(new AccommodationPhoto
            {
                AccommodationId = created.Id,
                Image = [1, 2, 3],
                ContentType = "image/jpeg",
                IsCover = true,
                DisplayOrder = 0,
                UploadedAt = DateTime.UtcNow,
            });

            db.AccommodationAvailability.Add(new AccommodationAvailability
            {
                AccommodationId = created.Id,
                StartDate = new DateOnly(2026, 9, 1),
                EndDate = new DateOnly(2026, 9, 30),
                IsAvailable = false,
            });

            await db.SaveChangesAsync();
        }

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.DeleteAsync(created.Id, CancellationToken.None));

        await using var check = fixture.CreateContext();

        Assert.False(await check.Accommodations.AnyAsync(row => row.Id == created.Id));
        Assert.False(
            await check.AccommodationPhotos.AnyAsync(row => row.AccommodationId == created.Id));
        Assert.False(
            await check.AccommodationAvailability.AnyAsync(
                row => row.AccommodationId == created.Id));
    }

    [Fact]
    public async Task AListingWithAReservationIsRefusedRatherThanDeleted()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, "A flat somebody booked"), CancellationToken.None));

        var now = DateTime.UtcNow;

        await using (var db = fixture.CreateContext())
        {
            db.Reservations.Add(new Reservation
            {
                UserId = guest,
                AccommodationId = created.Id,
                CheckInDate = new DateOnly(2026, 9, 1),
                CheckOutDate = new DateOnly(2026, 9, 5),
                GuestCount = 2,
                ReservationStatusId = (int)ReservationStatusCode.Confirmed,
                ExpiresAt = now.AddDays(1),
                AccommodationTotal = 400m,
                CleaningFee = 20m,
                TotalPrice = 420m,
                CreatedAt = now,
            });

            await db.SaveChangesAsync();
        }

        var refused = await Assert.ThrowsAsync<BusinessException>(() => AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.DeleteAsync(created.Id, CancellationToken.None)));

        Assert.Contains("Withdraw it", refused.Message);

        await using var check = fixture.CreateContext();

        Assert.True(await check.Accommodations.AnyAsync(row => row.Id == created.Id));
    }

    private static ICurrentUser Caller(int userId, params string[] roles) =>
        new SignedInUser(userId, roles);

    private async Task RefusedUnderAsync(int host, ListingReferences references, string field)
    {
        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                ListingRequests.New(references, $"Refused under {field}"),
                CancellationToken.None)));

        Assert.Contains(field, refused.Errors.Keys);
    }

    private async Task<IReadOnlyList<int>> BrowsedByAsync(ICurrentUser caller, int host)
    {
        var page = await AsAsync(
            caller,
            listings => listings.SearchAsync(
                new AccommodationSearchRequest { HostId = host }, CancellationToken.None));

        return [.. page.Items.Select(item => item.Id)];
    }

    private async Task<ListingReferences> ReferencesAsync() =>
        new(
            await fixture.EnsureCityAsync("Sarajevo"),
            await fixture.EnsureAccommodationTypeAsync("Apartment"),
            await fixture.EnsureAccommodationCategoryAsync("City break"));

    private async Task<T> AsAsync<T>(ICurrentUser caller, Func<IAccommodationService, Task<T>> work)
    {
        await using var services = fixture.BuildServices(caller);

        return await work(services.GetRequiredService<IAccommodationService>());
    }

    private async Task AsAsync(ICurrentUser caller, Func<IAccommodationService, Task> work)
    {
        await using var services = fixture.BuildServices(caller);

        await work(services.GetRequiredService<IAccommodationService>());
    }
}
