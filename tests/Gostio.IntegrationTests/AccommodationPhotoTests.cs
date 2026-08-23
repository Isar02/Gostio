using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Authentication;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class AccommodationPhotoTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-photo-owner";

    private readonly ListingWorkspace workspace = new(fixture);

    private static byte[] Jpeg => [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46];

    private static byte[] Png =>
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];

    private static byte[] Webp =>
        [0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50];

    // The first photo carries the cover, or a listing with pictures has none to
    // put beside its title.
    [Fact]
    public async Task TheFirstPhotoIsTheCoverAndTheOnesAfterItAreNot()
    {
        var (host, listing) = await AListingAsync();

        var first = await AddAsync(host, listing, Jpeg);
        var second = await AddAsync(host, listing, Jpeg);

        Assert.True(first.IsCover);
        Assert.False(second.IsCover);
        Assert.Equal(0, first.DisplayOrder);
        Assert.Equal(1, second.DisplayOrder);
    }

    [Theory]
    [InlineData("jpeg")]
    [InlineData("png")]
    [InlineData("webp")]
    public async Task ThePhotoIsStoredUnderTheTypeItsOwnBytesSay(string format)
    {
        var (host, listing) = await AListingAsync();

        var content = format switch
        {
            "png" => Png,
            "webp" => Webp,
            _ => Jpeg,
        };

        var expected = format switch
        {
            "png" => ImageRules.Png,
            "webp" => ImageRules.Webp,
            _ => ImageRules.Jpeg,
        };

        var stored = await AddAsync(host, listing, content);

        Assert.Equal(expected, stored.ContentType);

        var served = await AsHostAsync(
            host, photos => photos.GetContentAsync(listing, stored.Id, default));

        Assert.Equal(expected, served.ContentType);
        Assert.Equal(content, served.Content);
    }

    [Fact]
    public async Task SomethingThatIsNotAnImageIsRefusedWhateverItClaims()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, [0x25, 0x50, 0x44, 0x46, 0x2D]));

        Assert.Contains("File", refused.Errors.Keys);
    }

    [Fact]
    public async Task AnEmptyUploadIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, []));

        Assert.Contains("File", refused.Errors.Keys);
    }

    [Fact]
    public async Task AnImageOverTheCeilingIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var oversized = new byte[ImageRules.MaximumBytes + 1];

        Jpeg.CopyTo(oversized, 0);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, oversized));

        Assert.Contains("File", refused.Errors.Keys);
    }

    // One cover per listing is a unique index, so the old one has to go before
    // the new one lands.
    [Fact]
    public async Task PromotingAPhotoLeavesExactlyOneCover()
    {
        var (host, listing) = await AListingAsync();

        var first = await AddAsync(host, listing, Jpeg);
        var second = await AddAsync(host, listing, Png);

        var promoted = await AsHostAsync(
            host, photos => photos.SetCoverAsync(listing, second.Id, default));

        Assert.True(promoted.IsCover);
        Assert.Equal([second.Id], await CoversOfAsync(listing));

        var demoted = await AsHostAsync(
            host, photos => photos.GetAsync(listing, first.Id, default));

        Assert.False(demoted.IsCover);
    }

    [Fact]
    public async Task PromotingAPhotoThatIsNotThereLeavesTheCoverAlone()
    {
        var (host, listing) = await AListingAsync();

        var only = await AddAsync(host, listing, Jpeg);

        await Assert.ThrowsAsync<NotFoundException>(() => AsHostAsync(
            host, photos => photos.SetCoverAsync(listing, int.MaxValue, default)));

        Assert.Equal([only.Id], await CoversOfAsync(listing));
    }

    [Fact]
    public async Task DeletingTheCoverPromotesTheNextPhotoInOrder()
    {
        var (host, listing) = await AListingAsync();

        var first = await AddAsync(host, listing, Jpeg);
        var second = await AddAsync(host, listing, Png);

        await AsHostAsync(host, photos => photos.DeleteAsync(listing, first.Id, default));

        Assert.Equal([second.Id], await CoversOfAsync(listing));
    }

    [Fact]
    public async Task DeletingTheLastPhotoLeavesTheListingWithoutACover()
    {
        var (host, listing) = await AListingAsync();

        var only = await AddAsync(host, listing, Jpeg);

        await AsHostAsync(host, photos => photos.DeleteAsync(listing, only.Id, default));

        Assert.Empty(await CoversOfAsync(listing));

        var read = await workspace.AsHostAsync(
            host, (IAccommodationService listings) => listings.GetAsync(listing, default));

        Assert.Null(read.CoverPhotoId);
    }

    // The size is read out of the column rather than by loading the bytes, and
    // a member that did not translate would only fail here.
    [Fact]
    public async Task TheListSaysHowLargeEachPhotoIsWithoutCarryingIt()
    {
        var (host, listing) = await AListingAsync();

        await AddAsync(host, listing, Jpeg);

        var page = await AsHostAsync(
            host, photos => photos.SearchAsync(listing, new PagedRequest(), default));

        Assert.Equal(Jpeg.Length, page.Items.Single().SizeInBytes);
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task TheCoverReachesTheListingItBelongsTo()
    {
        var (host, listing) = await AListingAsync();

        var cover = await AddAsync(host, listing, Jpeg);

        var read = await workspace.AsHostAsync(
            host, (IAccommodationService listings) => listings.GetAsync(listing, default));

        Assert.Equal(cover.Id, read.CoverPhotoId);
    }

    [Fact]
    public async Task AnAccountThatDoesNotOwnTheListingCannotWriteToItsPhotos()
    {
        var (host, listing) = await AListingAsync();
        var stranger = await fixture.AddUserAsync(Password, RoleNames.Host);

        var mine = await AddAsync(host, listing, Jpeg);

        await Assert.ThrowsAsync<ForbiddenException>(() => AsHostAsync(
            stranger, photos => photos.AddAsync(listing, Upload(Png), default)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsHostAsync(
            stranger, photos => photos.SetCoverAsync(listing, mine.Id, default)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsHostAsync(
            stranger, photos => photos.DeleteAsync(listing, mine.Id, default)));
    }

    [Fact]
    public async Task AnAdministratorWritesToAnybodysPhotos()
    {
        var (host, listing) = await AListingAsync();
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);

        var added = await AsAsync(
            ListingWorkspace.Caller(administrator, RoleNames.Administrator),
            photos => photos.AddAsync(listing, Upload(Jpeg), default));

        Assert.True(added.IsCover);
    }

    // The photos follow the listing: one nobody may see hides its pictures too,
    // and answers the same 404 rather than admitting they are there.
    [Fact]
    public async Task ThePhotosOfAWithdrawnListingAreOutOfReach()
    {
        var (host, listing) = await AListingAsync();
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var photo = await AddAsync(host, listing, Jpeg);

        await WithdrawAsync(host, listing);

        var browsing = ListingWorkspace.Caller(guest, RoleNames.Guest);

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            browsing, photos => photos.SearchAsync(listing, new PagedRequest(), default)));

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            browsing, photos => photos.GetContentAsync(listing, photo.Id, default)));
    }

    [Fact]
    public async Task AClaimedTypeThatTheBytesContradictIsRefused()
    {
        var (host, listing) = await AListingAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => AddAsync(host, listing, Png, ImageRules.Jpeg));

        Assert.Contains("File", refused.Errors.Keys);
    }

    // The generic type is what a client sends when it did not look, which is no
    // claim at all rather than a wrong one.
    [Fact]
    public async Task AFileSentUnderTheGenericTypeIsTakenAtItsBytesWord()
    {
        var (host, listing) = await AListingAsync();

        var stored = await AddAsync(host, listing, Png, ImageRules.Unknown);

        Assert.Equal(ImageRules.Png, stored.ContentType);
    }

    [Fact]
    public async Task AClaimedTypeThatAgreesWithTheBytesIsKept()
    {
        var (host, listing) = await AListingAsync();

        var stored = await AsHostAsync(
            host,
            photos => photos.AddAsync(
                listing, Upload(Png, $"{ImageRules.Png}; charset=binary"), default));

        Assert.Equal(ImageRules.Png, stored.ContentType);
    }

    // Both callers are held at the lock and let go together, so they contend on
    // purpose rather than by luck. Without it they each read a listing that has
    // no cover yet and the second one loses its photo to the unique index; the
    // barrier names the statement, so removing the lock fails this outright.
    [Fact]
    public async Task TwoFirstUploadsAtOnceBothLandAndOnlyOneTakesTheCover()
    {
        var (host, listing) = await AListingAsync();

        var barrier = new CommandBarrier(callers: 2, "UPDLOCK");

        await Task.WhenAll(
            UploadAsync(host, listing, Jpeg, barrier),
            UploadAsync(host, listing, Png, barrier));

        Assert.Equal(2, barrier.Arrived);

        var photos = await PhotosOfAsync(listing);

        Assert.Equal(2, photos.Count);
        Assert.Single(photos, photo => photo.IsCover);
        Assert.Equal([0, 1], photos.Select(photo => photo.DisplayOrder).Order());
    }

    [Fact]
    public async Task TwoPromotionsAtOnceStillLeaveExactlyOneCover()
    {
        var (host, listing) = await AListingAsync();

        var first = await AddAsync(host, listing, Jpeg);
        var second = await AddAsync(host, listing, Png);

        var barrier = new CommandBarrier(callers: 2, "UPDLOCK");

        await Task.WhenAll(
            PromoteAsync(host, listing, first.Id, barrier),
            PromoteAsync(host, listing, second.Id, barrier));

        Assert.Equal(2, barrier.Arrived);
        Assert.Single(await CoversOfAsync(listing));
    }

    private static ImageUpload Upload(byte[] content, string? claimed = null) =>
        new(content, claimed);

    private Task<AccommodationPhotoResponse> AddAsync(
        int host,
        int listing,
        byte[] content,
        string? claimed = null) =>
        AsHostAsync(host, photos => photos.AddAsync(listing, Upload(content, claimed), default));

    private Task<(int Host, int Listing)> AListingAsync() => workspace.AListingAsync(Password);

    private Task WithdrawAsync(int host, int listing) => workspace.WithdrawAsync(host, listing);

    private async Task<IReadOnlyList<(int Id, bool IsCover, int DisplayOrder)>> PhotosOfAsync(
        int listing)
    {
        await using var db = fixture.CreateContext();

        var rows = await db.AccommodationPhotos
            .Where(photo => photo.AccommodationId == listing)
            .Select(photo => new { photo.Id, photo.IsCover, photo.DisplayOrder })
            .ToListAsync();

        return [.. rows.Select(row => (row.Id, row.IsCover, row.DisplayOrder))];
    }

    private Task UploadAsync(int host, int listing, byte[] content, IInterceptor barrier) =>
        workspace.AsAsync(
            ListingWorkspace.Caller(host, RoleNames.Host),
            (IAccommodationPhotoService photos) =>
                photos.AddAsync(listing, Upload(content), CancellationToken.None),
            barrier);

    private Task PromoteAsync(int host, int listing, int photoId, IInterceptor barrier) =>
        workspace.AsAsync(
            ListingWorkspace.Caller(host, RoleNames.Host),
            (IAccommodationPhotoService photos) =>
                photos.SetCoverAsync(listing, photoId, CancellationToken.None),
            barrier);

    private async Task<IReadOnlyList<int>> CoversOfAsync(int listing)
    {
        await using var db = fixture.CreateContext();

        return await db.AccommodationPhotos
            .Where(photo => photo.AccommodationId == listing && photo.IsCover)
            .Select(photo => photo.Id)
            .ToListAsync();
    }

    private Task<T> AsHostAsync<T>(int host, Func<IAccommodationPhotoService, Task<T>> work) =>
        workspace.AsHostAsync(host, work);

    private Task AsHostAsync(int host, Func<IAccommodationPhotoService, Task> work) =>
        workspace.AsHostAsync(host, work);

    private Task<T> AsAsync<T>(
        ICurrentUser caller,
        Func<IAccommodationPhotoService, Task<T>> work) =>
        workspace.AsAsync(caller, work);
}
