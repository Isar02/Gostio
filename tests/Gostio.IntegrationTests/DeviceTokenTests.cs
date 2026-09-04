using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Validation;
using Gostio.Services.Notifications;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// A device belongs to one account at a time, and both calls are the caller's
// own: neither takes an account id, so nobody registers or removes a device on
// somebody else's behalf.
[Collection(DatabaseCollection.Name)]
public class DeviceTokenTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-device";

    [Fact]
    public async Task ARegisteredDeviceIsKeptForTheAccountThatRegisteredIt()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var token = ADeviceToken();

        await RegisterAsync(userId, token);

        var device = Assert.Single(await DevicesOfAsync(userId));

        Assert.Equal(token, device.Token);
        Assert.Equal(DevicePlatform.Android, device.Platform);
        Assert.Equal(device.CreatedAt, device.ConfirmedAt);
    }

    [Fact]
    public async Task RegisteringTheSameDeviceAgainConfirmsItRatherThanAddingASecond()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var token = ADeviceToken();

        await RegisterAsync(userId, token);

        var first = Assert.Single(await DevicesOfAsync(userId));

        await RegisterAsync(userId, token);

        var again = Assert.Single(await DevicesOfAsync(userId));

        Assert.Equal(first.CreatedAt, again.CreatedAt);
        Assert.True(again.ConfirmedAt >= first.ConfirmedAt);
    }

    // A phone that changes hands cannot hold two accounts' registrations at
    // once, or the account that let it go keeps getting its notices.
    [Fact]
    public async Task ADeviceRegisteredByASecondAccountMovesToThatAccount()
    {
        var first = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var second = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var token = ADeviceToken();

        await RegisterAsync(first, token);
        await RegisterAsync(second, token, DevicePlatform.Ios);

        Assert.Empty(await DevicesOfAsync(first));

        var moved = Assert.Single(await DevicesOfAsync(second));

        Assert.Equal(token, moved.Token);
        Assert.Equal(DevicePlatform.Ios, moved.Platform);
    }

    [Fact]
    public async Task SigningOutRemovesTheCallersDeviceAndNobodyElses()
    {
        var caller = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var other = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var callersToken = ADeviceToken();
        var othersToken = ADeviceToken();

        await RegisterAsync(caller, callersToken);
        await RegisterAsync(other, othersToken);

        await ForgetAsync(caller, othersToken);

        Assert.Single(await DevicesOfAsync(caller));
        Assert.Single(await DevicesOfAsync(other));

        await ForgetAsync(caller, callersToken);

        Assert.Empty(await DevicesOfAsync(caller));
        Assert.Single(await DevicesOfAsync(other));
    }

    [Fact]
    public async Task ARegistrationThatNamesNoDeviceIsRefused()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(userId, new DeviceTokenRequest
            {
                Platform = DevicePlatform.Android,
            }));

        Assert.Contains(nameof(DeviceTokenRequest.Token), refused.Errors.Keys);
    }

    [Fact]
    public async Task ARegistrationThatNamesNoPlatformIsRefused()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(userId, new DeviceTokenRequest { Token = ADeviceToken() }));

        Assert.Contains(nameof(DeviceTokenRequest.Platform), refused.Errors.Keys);
    }

    // Refused where it is read rather than by the column it would not fit.
    [Fact]
    public async Task ATokenLongerThanTheColumnIsRefused()
    {
        var userId = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(userId, new DeviceTokenRequest
            {
                Token = new string('t', ColumnLengths.DeviceToken + 1),
                Platform = DevicePlatform.Android,
            }));

        Assert.Contains(nameof(DeviceTokenRequest.Token), refused.Errors.Keys);
    }

    private static string ADeviceToken() => $"device-{Guid.NewGuid():N}";

    private Task RegisterAsync(
        int userId,
        string token,
        DevicePlatform platform = DevicePlatform.Android) =>
        RegisterAsync(userId, new DeviceTokenRequest { Token = token, Platform = platform });

    private async Task RegisterAsync(int userId, DeviceTokenRequest request)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(userId, RoleNames.Guest));

        await services
            .GetRequiredService<IDeviceTokenService>()
            .RegisterAsync(request, default);
    }

    private async Task ForgetAsync(int userId, string token)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(userId, RoleNames.Guest));

        await services
            .GetRequiredService<IDeviceTokenService>()
            .ForgetAsync(new DeviceTokenRequest { Token = token }, default);
    }

    private async Task<List<DeviceRow>> DevicesOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.DeviceTokens
            .AsNoTracking()
            .Where(device => device.UserId == userId)
            .OrderBy(device => device.Id)
            .Select(device => new DeviceRow(
                device.Token, device.Platform, device.CreatedAt, device.ConfirmedAt))
            .ToListAsync();
    }

    private sealed record DeviceRow(
        string Token,
        DevicePlatform Platform,
        DateTime CreatedAt,
        DateTime ConfirmedAt);
}
