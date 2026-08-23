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

    private sealed record References(int CityId, int TypeId, int CategoryId);

    [Fact]
    public async Task AHostKeepsTheListingTheyCreate()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(references, "  A loft over the river  "), CancellationToken.None));

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
                NewListing(references, "A stone house", hostId: host), CancellationToken.None));

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
                NewListing(references, "A room a guest cannot let"), CancellationToken.None)));

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
                NewListing(references, "Not mine to give", hostId: theirs),
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
                NewListing(references, "A flat by the market"), CancellationToken.None));

        var saved = await AsAsync(
            Caller(mine, RoleNames.Host),
            listings => listings.UpdateAsync(
                created.Id,
                Edit(references, "A quieter flat by the market", price: 140m),
                CancellationToken.None));

        Assert.Equal("A quieter flat by the market", saved.Title);
        Assert.Equal(140m, saved.PricePerNight);

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(theirs, RoleNames.Host),
            listings => listings.UpdateAsync(
                created.Id, Edit(references, "Taken over"), CancellationToken.None)));

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
                NewListing(references, "A cottage by the lake"), CancellationToken.None));

        var saved = await AsAsync(
            Caller(administrator, RoleNames.Administrator),
            listings => listings.UpdateAsync(
                created.Id,
                Edit(references, "A cottage by the lake", isActive: false),
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
                NewListing(references, "Still on the market"), CancellationToken.None));

        var withdrawn = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(references, "Taken off the market"), CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.UpdateAsync(
                withdrawn.Id,
                Edit(references, "Taken off the market", isActive: false),
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
        var elsewhere = here with { CityId = await EnsureCityAsync("Mostar") };

        var wanted = await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(here, "Four beds at ninety", price: 90m, maxGuests: 4),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(here, "Four beds at three hundred", price: 300m, maxGuests: 4),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(here, "Two beds at ninety", price: 90m, maxGuests: 2),
                CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(elsewhere, "Four beds at ninety, elsewhere", price: 90m, maxGuests: 4),
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
                NewListing(references, "An attic with a skylight"), CancellationToken.None));

        await AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(references, "A basement with no window"), CancellationToken.None));

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
                NewListing(references, "A studio nobody booked"), CancellationToken.None));

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
                NewListing(references, "A flat somebody booked"), CancellationToken.None));

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

    private static AccommodationCreateRequest NewListing(
        References references,
        string title,
        int? hostId = null,
        decimal price = 100m,
        int maxGuests = 4) =>
        new()
        {
            HostId = hostId,
            Title = title,
            Description = "A place to stay, described at the length a listing needs.",
            AccommodationTypeId = references.TypeId,
            AccommodationCategoryId = references.CategoryId,
            CityId = references.CityId,
            Address = "Ferhadija 1",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            MaxGuests = maxGuests,
            Bedrooms = 2,
            Bathrooms = 1,
            PricePerNight = price,
            CleaningFee = 15m,
        };

    private static AccommodationUpdateRequest Edit(
        References references,
        string title,
        bool isActive = true,
        decimal price = 100m) =>
        new()
        {
            IsActive = isActive,
            Title = title,
            Description = "A place to stay, described at the length a listing needs.",
            AccommodationTypeId = references.TypeId,
            AccommodationCategoryId = references.CategoryId,
            CityId = references.CityId,
            Address = "Ferhadija 1",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            MaxGuests = 4,
            Bedrooms = 2,
            Bathrooms = 1,
            PricePerNight = price,
            CleaningFee = 15m,
        };

    private async Task RefusedUnderAsync(int host, References references, string field)
    {
        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAsync(
            Caller(host, RoleNames.Host),
            listings => listings.CreateAsync(
                NewListing(references, $"Refused under {field}"), CancellationToken.None)));

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

    private async Task<References> ReferencesAsync() =>
        new(
            await EnsureCityAsync("Sarajevo"),
            await EnsureTypeAsync(),
            await EnsureCategoryAsync());

    private async Task<int> EnsureCityAsync(string name)
    {
        await using var db = fixture.CreateContext();

        var country = await db.Countries.FirstOrDefaultAsync(row => row.IsoCode == "BA");

        if (country is null)
        {
            country = new Country { Name = "Bosnia and Herzegovina", IsoCode = "BA" };

            db.Countries.Add(country);
            await db.SaveChangesAsync();
        }

        var city = await db.Cities.FirstOrDefaultAsync(
            row => row.CountryId == country.Id && row.Name == name);

        if (city is null)
        {
            city = new City { Name = name, CountryId = country.Id };

            db.Cities.Add(city);
            await db.SaveChangesAsync();
        }

        return city.Id;
    }

    private async Task<int> EnsureTypeAsync()
    {
        await using var db = fixture.CreateContext();

        var type = await db.AccommodationTypes.FirstOrDefaultAsync(row => row.Name == "Apartment");

        if (type is null)
        {
            type = new AccommodationType { Name = "Apartment" };

            db.AccommodationTypes.Add(type);
            await db.SaveChangesAsync();
        }

        return type.Id;
    }

    private async Task<int> EnsureCategoryAsync()
    {
        await using var db = fixture.CreateContext();

        var category = await db.AccommodationCategories.FirstOrDefaultAsync(
            row => row.Name == "City break");

        if (category is null)
        {
            category = new AccommodationCategory { Name = "City break" };

            db.AccommodationCategories.Add(category);
            await db.SaveChangesAsync();
        }

        return category.Id;
    }

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
