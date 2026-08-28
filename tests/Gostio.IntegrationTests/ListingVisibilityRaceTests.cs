using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Authentication;
using Gostio.Services.Listings;

namespace Gostio.IntegrationTests;

// A child resource is readable only while its listing is. Checking that in a
// statement of its own leaves a gap: the listing can be withdrawn after the
// check and before the read, and the read would then hand back rows the check
// would now refuse. Each test here withdraws the listing in exactly that gap,
// so the gate has to sit inside the statement that reads the rows.
[Collection(DatabaseCollection.Name)]
public class ListingVisibilityRaceTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-listing-withdrawn-mid-read";

    private readonly AccommodationWorkspace workspace = new(fixture);

    [Fact]
    public async Task APhotoListIsRefusedWhenTheListingIsWithdrawnMidRead()
    {
        var (host, listing, _) = await AListingWithAPhotoAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationPhotos]",
            (IAccommodationPhotoService photos) =>
                photos.SearchAsync(listing, new PagedRequest(), default),
            listing));
    }

    [Fact]
    public async Task APhotoIsRefusedWhenTheListingIsWithdrawnMidRead()
    {
        var (host, listing, photoId) = await AListingWithAPhotoAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationPhotos]",
            (IAccommodationPhotoService photos) => photos.GetAsync(listing, photoId, default),
            listing));
    }

    [Fact]
    public async Task ThePhotoContentIsRefusedWhenTheListingIsWithdrawnMidRead()
    {
        var (host, listing, photoId) = await AListingWithAPhotoAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationPhotos]",
            (IAccommodationPhotoService photos) => photos.GetContentAsync(listing, photoId, default),
            listing));
    }

    // A page is two statements, so it has a gap of its own between them. The
    // count is taken while the listing is visible and the rows are fetched after
    // it is not, which is the one case a count-based check would wave through.
    [Fact]
    public async Task APhotoListIsRefusedWhenTheListingGoesBetweenTheCountAndTheRows()
    {
        var (host, listing, _) = await AListingWithAPhotoAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationPhotos]",
            (IAccommodationPhotoService photos) =>
                photos.SearchAsync(listing, new PagedRequest(), default),
            listing,
            after: 1));
    }

    [Fact]
    public async Task TheAvailabilityIsRefusedWhenTheListingGoesBetweenTheCountAndTheRows()
    {
        var (host, listing) = await AListingWithARangeAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationAvailability]",
            (IAccommodationAvailabilityService ranges) =>
                ranges.SearchAsync(listing, new(), default),
            listing,
            after: 1));
    }

    [Fact]
    public async Task ARangeIsRefusedWhenTheListingIsWithdrawnMidRead()
    {
        var (host, listing) = await AListingWithARangeAsync();

        var range = await workspace.AsHostAsync(
            host,
            (IAccommodationAvailabilityService ranges) =>
                ranges.SearchAsync(listing, new(), default));

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationAvailability]",
            (IAccommodationAvailabilityService ranges) =>
                ranges.GetAsync(listing, range.Items.Single().Id, default),
            listing));
    }

    [Fact]
    public async Task TheAmenitiesAreRefusedWhenTheListingIsWithdrawnMidRead()
    {
        var (host, listing) = await workspace.AListingAsync(Password);
        var wifi = await fixture.EnsureAmenityAsync("Wi-Fi");

        await workspace.AsHostAsync(
            host,
            (IAccommodationAmenityService amenities) => amenities.SetAsync(
                listing, new() { AmenityIds = [wifi] }, default));

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationAmenities]",
            (IAccommodationAmenityService amenities) => amenities.GetAsync(
                listing, new PagedRequest(), default),
            listing));
    }

    [Fact]
    public async Task TheAvailabilityIsRefusedWhenTheListingIsWithdrawnMidRead()
    {
        var (host, listing) = await AListingWithARangeAsync();

        await Assert.ThrowsAsync<NotFoundException>(() => ReadAsync(
            host,
            "[AccommodationAvailability]",
            (IAccommodationAvailabilityService ranges) =>
                ranges.SearchAsync(listing, new(), default),
            listing));
    }

    private async Task<(int Host, int Listing)> AListingWithARangeAsync()
    {
        var (host, listing) = await workspace.AListingAsync(Password);
        var today = DateOnly.FromDateTime(DateTime.UtcNow.Date);

        await workspace.AsHostAsync(
            host,
            (IAccommodationAvailabilityService ranges) => ranges.AddAsync(
                listing,
                new()
                {
                    StartDate = today.AddDays(10),
                    EndDate = today.AddDays(14),
                    IsAvailable = false,
                },
                default));

        return (host, listing);
    }

    private async Task<(int Host, int Listing, int PhotoId)> AListingWithAPhotoAsync()
    {
        var (host, listing) = await workspace.AListingAsync(Password);

        var photo = await workspace.AsHostAsync(
            host,
            (IAccommodationPhotoService photos) => photos.AddAsync(
                listing,
                new ImageUpload([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46], null),
                default));

        return (host, listing, photo.Id);
    }

    // The guest may read the listing right up until the interceptor withdraws
    // it, so anything refused here was refused by the read itself.
    private async Task<TResult> ReadAsync<TService, TResult>(
        int host,
        string table,
        Func<TService, Task<TResult>> work,
        int listing,
        int after = 0)
        where TService : notnull
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var withdrawing = new RaceInterceptor(
            table, () => workspace.WithdrawAsync(host, listing), after);

        try
        {
            return await workspace.AsAsync(
                ListingWorkspace.Caller(guest, RoleNames.Guest), work, withdrawing);
        }
        finally
        {
            Assert.True(withdrawing.Fired, $"Nothing matching {table} was intercepted.");
        }
    }
}
