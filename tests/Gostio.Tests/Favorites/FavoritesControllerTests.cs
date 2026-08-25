using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Services.Favorites;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Favorites;

public sealed class FavoritesControllerTests : IAsyncLifetime
{
    private const string Route = "/api/favorites";

    private readonly StubFavorites favorites = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IFavoriteService>(favorites));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task TheListIsOpenToAnySignedInAccount(string role)
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheListCarriesItsFilterThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?target=Experiences&pageSize=5", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(SearchTarget.Experiences, favorites.LastSearch?.Target);
        Assert.Equal(5, favorites.LastSearch?.PageSize);
    }

    [Fact]
    public async Task TheListIsNotReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
