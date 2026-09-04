using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Authentication;
using Gostio.Services.Database.Entities;
using Gostio.Services.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class AdministratorPasswordTests(DatabaseFixture fixture)
{
    private const string OldPassword = "the-old-password";

    private const string NewPassword = "the-password-chosen-for-them";

    [Fact]
    public async Task TheAccountSignsInWithTheNewPasswordAndNotTheOldOne()
    {
        var administrator = await fixture.AddUserAsync(OldPassword, RoleNames.Administrator);
        var account = await fixture.AddUserAsync(OldPassword, RoleNames.Guest);

        await SetAsync(administrator, account, NewPassword);

        var username = await UsernameOfAsync(account);

        await SignInAsync(username, NewPassword);

        await Assert.ThrowsAsync<UnauthorizedException>(
            () => SignInAsync(username, OldPassword));
    }

    [Fact]
    public async Task EverySessionTheAccountHeldStopsBeingCurrent()
    {
        var administrator = await fixture.AddUserAsync(OldPassword, RoleNames.Administrator);
        var account = await fixture.AddUserAsync(OldPassword, RoleNames.Guest);
        var held = await VersionOfAsync(account);

        await SetAsync(administrator, account, NewPassword);

        Assert.Equal(held + 1, await VersionOfAsync(account));
        Assert.False(await IsCurrentAsync(account, held));
        Assert.True(await IsCurrentAsync(account, held + 1));
    }

    [Fact]
    public async Task TheAdministratorsOwnPasswordIsNotSetThisWay()
    {
        var administrator = await fixture.AddUserAsync(OldPassword, RoleNames.Administrator);
        var held = await VersionOfAsync(administrator);

        await Assert.ThrowsAsync<BusinessException>(
            () => SetAsync(administrator, administrator, NewPassword));

        Assert.True(PasswordHasher.Verify(OldPassword, await HashOfAsync(administrator)));
        Assert.Equal(held, await VersionOfAsync(administrator));
    }

    [Fact]
    public async Task AnIdNoAccountHasIsANotFound()
    {
        var administrator = await fixture.AddUserAsync(OldPassword, RoleNames.Administrator);

        await Assert.ThrowsAsync<NotFoundException>(
            () => SetAsync(administrator, int.MaxValue, NewPassword));
    }

    private async Task SetAsync(int administrator, int account, string password)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(administrator, RoleNames.Administrator));

        await services.GetRequiredService<IUserService>().SetPasswordAsync(
            account,
            new NewPasswordRequest { NewPassword = password, ConfirmNewPassword = password },
            CancellationToken.None);
    }

    private async Task SignInAsync(string username, string password)
    {
        await using var db = fixture.CreateContext();

        var auth = new AuthService(
            db,
            new JwtTokenService(fixture.Jwt),
            new AnonymousUser(),
            new CapturedNotices());

        await auth.LoginAsync(
            new LoginRequest { Username = username, Password = password },
            CancellationToken.None);
    }

    private async Task<bool> IsCurrentAsync(int userId, int tokenVersion)
    {
        await using var db = fixture.CreateContext();

        return await new UserSessionValidator(db).IsCurrentAsync(
            userId, tokenVersion, CancellationToken.None);
    }

    private Task<string> UsernameOfAsync(int userId) => ReadAsync(userId, user => user.Username);

    private Task<string> HashOfAsync(int userId) => ReadAsync(userId, user => user.PasswordHash);

    private Task<int> VersionOfAsync(int userId) => ReadAsync(userId, user => user.TokenVersion);

    private async Task<T> ReadAsync<T>(int userId, Func<User, T> read)
    {
        await using var db = fixture.CreateContext();

        return read(await db.Users.SingleAsync(user => user.Id == userId));
    }
}
