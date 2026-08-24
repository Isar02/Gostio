using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class AccommodationAmenityTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-an-amenity-owner";

    private readonly AccommodationWorkspace workspace = new(fixture);

    [Fact]
    public async Task TheSetTheCallSendsIsTheSetTheListingKeeps()
    {
        var (host, listing) = await AListingAsync();
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");
        var parking = await fixture.EnsureAmenityAsync("Parking");
        var kitchen = await fixture.EnsureAmenityAsync("Kitchen");

        await SetAsync(host, listing, [wifi, parking]);

        var replaced = await SetAsync(host, listing, [parking, kitchen]);

        Assert.Equal([parking, kitchen], replaced.Select(amenity => amenity.Id).Order());
    }

    [Fact]
    public async Task AnEmptyListLeavesTheListingOfferingNothing()
    {
        var (host, listing) = await AListingAsync();
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        await SetAsync(host, listing, [wifi]);

        Assert.Empty(await SetAsync(host, listing, []));
    }

    [Fact]
    public async Task TheSameAmenityNamedTwiceIsStoredOnce()
    {
        var (host, listing) = await AListingAsync();
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        var stored = await SetAsync(host, listing, [wifi, wifi]);

        Assert.Equal([wifi], stored.Select(amenity => amenity.Id));
    }

    // The whole call is refused rather than the good half of it applied, or a
    // typo in one id would silently drop everything the listing already offers.
    [Fact]
    public async Task AnUnknownAmenityIsRefusedAndLeavesTheSetAlone()
    {
        var (host, listing) = await AListingAsync();
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        await SetAsync(host, listing, [wifi]);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => SetAsync(host, listing, [wifi, int.MaxValue]));

        Assert.Contains(nameof(AccommodationAmenitiesRequest.AmenityIds), refused.Errors.Keys);
        Assert.Equal([wifi], await StoredIdsAsync(listing));
    }

    [Fact]
    public async Task AnAbsentListIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsHostAsync(
            host, amenities => amenities.SetAsync(listing, new(), default)));

        Assert.Contains(nameof(AccommodationAmenitiesRequest.AmenityIds), refused.Errors.Keys);
    }

    [Fact]
    public async Task TheSetComesBackInNameOrder()
    {
        var (host, listing) = await AListingAsync();
        var washer = await fixture.EnsureAmenityAsync("Washer");
        var airConditioning = await fixture.EnsureAmenityAsync("Air conditioning");
        var kitchen = await fixture.EnsureAmenityAsync("Kitchen");

        var stored = await SetAsync(host, listing, [washer, airConditioning, kitchen]);

        Assert.Equal(
            ["Air conditioning", "Kitchen", "Washer"],
            stored.Select(amenity => amenity.Name));
    }

    [Fact]
    public async Task AnAccountThatDoesNotOwnTheListingCannotWriteItsAmenities()
    {
        var (host, listing) = await AListingAsync();
        var stranger = await fixture.AddUserAsync(Password, RoleNames.Host);
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        await Assert.ThrowsAsync<ForbiddenException>(() => SetAsync(stranger, listing, [wifi]));
    }

    [Fact]
    public async Task AnAdministratorWritesAnybodysAmenities()
    {
        var (_, listing) = await AListingAsync();
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        var stored = await AsAsync(
            ListingWorkspace.Caller(administrator, RoleNames.Administrator),
            amenities => amenities.SetAsync(
                listing, new() { AmenityIds = [wifi] }, default));

        Assert.Equal([wifi], stored.Select(amenity => amenity.Id));
    }

    // The amenities follow the listing: one nobody may see hides them too, and
    // answers the same 404 rather than admitting it is there.
    [Fact]
    public async Task TheAmenitiesOfAWithdrawnListingAreOutOfReach()
    {
        var (host, listing) = await AListingAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        await SetAsync(host, listing, [wifi]);
        await WithdrawAsync(host, listing);

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            ListingWorkspace.Caller(guest, RoleNames.Guest),
            amenities => amenities.GetAsync(listing, default)));
    }

    // A search naming two amenities is naming both of them, so a listing that
    // offers one of the two is not an answer to it.
    [Fact]
    public async Task ASearchFindsOnlyTheListingsCarryingEveryAmenityItNames()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var marker = $"amenity search {Guid.NewGuid():N}";

        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");
        var parking = await fixture.EnsureAmenityAsync("Parking");

        var both = await workspace.CreateAsync(host, $"{marker} both");
        var onlyWifi = await workspace.CreateAsync(host, $"{marker} one");

        await SetAsync(host, both, [wifi, parking]);
        await SetAsync(host, onlyWifi, [wifi]);

        var found = await workspace.AsHostAsync(
            host,
            (IAccommodationService listings) => listings.SearchAsync(
                new AccommodationSearchRequest { Title = marker, AmenityIds = [wifi, parking] },
                default));

        Assert.Equal([both], found.Items.Select(listing => listing.Id));
    }

    // Both callers are held at the lock and let go together, so they contend on
    // purpose rather than by luck. Without it they each read a listing that
    // offers nothing yet and the second loses its write to the composite key.
    [Fact]
    public async Task TwoReplacementsAtOnceBothLandAndTheLastOneWins()
    {
        var (host, listing) = await AListingAsync();
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");
        var parking = await fixture.EnsureAmenityAsync("Parking");
        var kitchen = await fixture.EnsureAmenityAsync("Kitchen");

        var barrier = new CommandBarrier(callers: 2, "UPDLOCK");

        await Task.WhenAll(
            ReplaceAsync(host, listing, [wifi, parking], barrier),
            ReplaceAsync(host, listing, [parking, kitchen], barrier));

        Assert.Equal(2, barrier.Arrived);

        var stored = await StoredIdsAsync(listing);

        int[] first = [.. new[] { wifi, parking }.Order()];
        int[] second = [.. new[] { parking, kitchen }.Order()];

        Assert.True(
            stored.SequenceEqual(first) || stored.SequenceEqual(second),
            $"The set was left as [{string.Join(", ", stored)}], which neither call asked for.");
    }

    private Task<IReadOnlyList<LookupResponse>> SetAsync(
        int host,
        int listing,
        List<int> amenityIds) =>
        AsHostAsync(host, amenities => amenities.SetAsync(
            listing, new() { AmenityIds = amenityIds }, default));

    private Task ReplaceAsync(
        int host,
        int listing,
        List<int> amenityIds,
        IInterceptor barrier) =>
        workspace.AsAsync(
            ListingWorkspace.Caller(host, RoleNames.Host),
            (IAccommodationAmenityService amenities) => amenities.SetAsync(
                listing, new() { AmenityIds = amenityIds }, CancellationToken.None),
            barrier);

    private async Task<IReadOnlyList<int>> StoredIdsAsync(int listing)
    {
        await using var db = fixture.CreateContext();

        return await db.AccommodationAmenities
            .Where(offering => offering.AccommodationId == listing)
            .Select(offering => offering.AmenityId)
            .OrderBy(amenityId => amenityId)
            .ToListAsync();
    }

    private Task<(int Host, int Listing)> AListingAsync() => workspace.AListingAsync(Password);

    private Task WithdrawAsync(int host, int listing) => workspace.WithdrawAsync(host, listing);

    private Task<TResult> AsHostAsync<TResult>(
        int host,
        Func<IAccommodationAmenityService, Task<TResult>> work) =>
        workspace.AsHostAsync(host, work);

    private Task<TResult> AsAsync<TResult>(
        ICurrentUser caller,
        Func<IAccommodationAmenityService, Task<TResult>> work) =>
        workspace.AsAsync(caller, work);
}
