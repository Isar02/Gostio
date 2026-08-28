using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;
using Gostio.Services.Users;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Users;

public sealed class UserImageTests : IAsyncLifetime
{
    private const string Mine = "/api/users/me/image";

    private readonly StubUsers users = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services => services.AddSingleton<IUserService>(users));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Fact]
    public async Task TheBytesAndTheTypeTheFormClaimsReachTheServiceWhole()
    {
        await host.SendAsync(HttpMethod.Put, Mine, RoleNames.Guest, UserImages.Form());

        Assert.Equal(StubUsers.Bytes, users.LastImage!.Content);
        Assert.Equal(ImageRules.Jpeg, users.LastImage.ContentType);
    }

    [Fact]
    public async Task AFormCarryingNoFileIsRefusedBeforeTheServiceSeesIt()
    {
        var response = await host.SendAsync(
            HttpMethod.Put, Mine, RoleNames.Guest, UserImages.Form(withFile: false));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(users.LastImage);
    }

    // The account comes off the token, so there is no id on this path for a
    // caller to send and none for the service to check.
    [Fact]
    public async Task NeitherWriteUnderMeNamesAnAccount()
    {
        await host.SendAsync(HttpMethod.Put, Mine, RoleNames.Guest, UserImages.Form());
        await host.SendAsync(HttpMethod.Delete, Mine, RoleNames.Guest);

        Assert.True(users.MineWasNamed);
        Assert.Null(users.LastImageOwner);
        Assert.Null(users.LastImageCleared);
    }

    [Fact]
    public async Task AnAdministratorWritesThePictureOfTheAccountThePathNames()
    {
        await host.SendAsync(
            HttpMethod.Put, "/api/users/7/image", RoleNames.Administrator, UserImages.Form());

        await host.SendAsync(HttpMethod.Delete, "/api/users/8/image", RoleNames.Administrator);

        Assert.Equal(7, users.LastImageOwner);
        Assert.Equal(8, users.LastImageCleared);
        Assert.False(users.MineWasNamed);
    }

    [Fact]
    public async Task ThePictureIsServedUnderTheTypeItIsStoredWith()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, "/api/users/5/image", RoleNames.Guest);

        Assert.Equal(ImageRules.Jpeg, response.Content.Headers.ContentType!.MediaType);
        Assert.Equal(StubUsers.Bytes, await response.Content.ReadAsByteArrayAsync());
    }
}
