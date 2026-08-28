using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class UserImageTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-picture-owner";

    private static byte[] Jpeg => [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46];

    private static byte[] Png =>
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];

    private static byte[] Webp =>
        [0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50];

    [Fact]
    public async Task APictureIsUploadedServedAndTakenDownAgain()
    {
        var mine = await fixture.AddUserAsync(Password);

        var saved = await AsMineAsync(
            mine, users => users.SetMineImageAsync(Upload(Jpeg), default));

        Assert.True(saved.HasProfileImage);

        var served = await AsMineAsync(mine, users => users.GetImageAsync(mine, default));

        Assert.Equal(Jpeg, served.Content);
        Assert.Equal(ImageRules.Jpeg, served.ContentType);

        await AsMineAsync(mine, users => users.ClearMineImageAsync(default));

        var read = await AsMineAsync(mine, users => users.GetMineAsync(default));

        Assert.False(read.HasProfileImage);
        Assert.Equal((null, null), await StoredAsync(mine));
    }

    [Theory]
    [InlineData("jpeg")]
    [InlineData("png")]
    [InlineData("webp")]
    public async Task ThePictureIsStoredUnderTheTypeItsOwnBytesSay(string format)
    {
        var mine = await fixture.AddUserAsync(Password);

        var (content, expected) = format switch
        {
            "png" => (Png, ImageRules.Png),
            "webp" => (Webp, ImageRules.Webp),
            _ => (Jpeg, ImageRules.Jpeg),
        };

        await AsMineAsync(mine, users => users.SetMineImageAsync(Upload(content), default));

        var served = await AsMineAsync(mine, users => users.GetImageAsync(mine, default));

        Assert.Equal(expected, served.ContentType);
        Assert.Equal(content, served.Content);
    }

    [Fact]
    public async Task SomethingThatIsNotAnImageIsRefusedWhateverItIsCalled()
    {
        var mine = await fixture.AddUserAsync(Password);

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsMineAsync(
            mine,
            users => users.SetMineImageAsync(Upload([0x25, 0x50, 0x44, 0x46, 0x2D]), default)));

        Assert.Contains("File", refused.Errors.Keys);
        Assert.Equal((null, null), await StoredAsync(mine));
    }

    [Fact]
    public async Task AnImageOverTheCeilingIsRefused()
    {
        var mine = await fixture.AddUserAsync(Password);

        var oversized = new byte[ImageRules.MaximumBytes + 1];

        Jpeg.CopyTo(oversized, 0);

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsMineAsync(
            mine, users => users.SetMineImageAsync(Upload(oversized), default)));

        Assert.Contains("File", refused.Errors.Keys);
    }

    // An account that has no picture and an id that names nobody are both a
    // 404, and a client fetching an avatar has to be able to tell them apart.
    [Fact]
    public async Task AnAccountWithNoPictureAndAnAccountThatDoesNotExistAnswerDifferently()
    {
        var mine = await fixture.AddUserAsync(Password);

        var bare = await Assert.ThrowsAsync<NotFoundException>(
            () => AsMineAsync(mine, users => users.GetImageAsync(mine, default)));

        var unknown = await Assert.ThrowsAsync<NotFoundException>(
            () => AsMineAsync(mine, users => users.GetImageAsync(0, default)));

        Assert.Contains("has no picture", bare.Message);
        Assert.Contains("No user has the id", unknown.Message);
    }

    [Fact]
    public async Task WritingUnderMeTouchesTheAccountTheTokenNamesAndNoOther()
    {
        var mine = await fixture.AddUserAsync(Password);
        var theirs = await fixture.AddUserAsync(Password);

        await AsMineAsync(mine, users => users.SetMineImageAsync(Upload(Jpeg), default));

        Assert.Equal((null, null), await StoredAsync(theirs));
    }

    [Fact]
    public async Task AnAdministratorReplacesAndTakesDownAnybodysPicture()
    {
        var theirs = await fixture.AddUserAsync(Password);

        var saved = await AsAdministratorAsync(
            users => users.SetImageAsync(theirs, Upload(Png), default));

        Assert.True(saved.HasProfileImage);

        await AsAdministratorAsync(users => users.ClearImageAsync(theirs, default));

        Assert.Equal((null, null), await StoredAsync(theirs));
    }

    // Taking down a picture is the same statement whether one is there or not,
    // so asking twice is not an error, while an id nobody carries still is.
    [Fact]
    public async Task ClearingAPictureTwiceIsNoErrorAndClearingOneNobodyHasIs()
    {
        var theirs = await fixture.AddUserAsync(Password);

        await AsAdministratorAsync(users => users.ClearImageAsync(theirs, default));
        await AsAdministratorAsync(users => users.ClearImageAsync(theirs, default));

        await Assert.ThrowsAsync<NotFoundException>(
            () => AsAdministratorAsync(users => users.ClearImageAsync(0, default)));
    }

    private static ImageUpload Upload(byte[] content) => new(content, null);

    private async Task<(byte[]? Content, string? ContentType)> StoredAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        var row = await db.Users
            .Where(user => user.Id == userId)
            .Select(user => new { user.ProfileImage, user.ProfileImageContentType })
            .SingleAsync();

        return (row.ProfileImage, row.ProfileImageContentType);
    }

    private async Task<T> AsMineAsync<T>(int userId, Func<IUserService, Task<T>> work)
    {
        await using var services = fixture.BuildServices(new SignedInUser(userId, RoleNames.Guest));

        return await work(services.GetRequiredService<IUserService>());
    }

    private async Task AsMineAsync(int userId, Func<IUserService, Task> work)
    {
        await using var services = fixture.BuildServices(new SignedInUser(userId, RoleNames.Guest));

        await work(services.GetRequiredService<IUserService>());
    }

    private async Task<T> AsAdministratorAsync<T>(Func<IUserService, Task<T>> work)
    {
        await using var services = fixture.BuildServices(
            new SignedInUser(0, RoleNames.Administrator));

        return await work(services.GetRequiredService<IUserService>());
    }

    private async Task AsAdministratorAsync(Func<IUserService, Task> work)
    {
        await using var services = fixture.BuildServices(
            new SignedInUser(0, RoleNames.Administrator));

        await work(services.GetRequiredService<IUserService>());
    }
}
