using System.Net;
using Gostio.Model.Authorization;
using Gostio.Services.Favorites;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Favorites;

public sealed class ListingFavoriteControllerTests : IAsyncLifetime
{
    private const string Stay = "/api/accommodations/7/favorite";

    private const string Term = "/api/experiences/7/favorite";

    private readonly StubFavorites favorites = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services =>
        {
            services.AddSingleton<IAccommodationFavoriteService>(favorites);
            services.AddSingleton<IExperienceFavoriteService>(favorites);
        });

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(Stay)]
    [InlineData(Term)]
    public async Task KeepingOneNamesTheListingItWasAskedFor(string path)
    {
        var response = await host.SendAsync(HttpMethod.Put, path, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(7, favorites.LastKept);
    }

    [Theory]
    [InlineData(Stay)]
    [InlineData(Term)]
    public async Task DroppingOneAnswersWithNothing(string path)
    {
        var response = await host.SendAsync(HttpMethod.Delete, path, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(7, favorites.LastDropped);
    }

    [Theory]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task EveryRoleKeepsListingsOfItsOwn(string role)
    {
        var response = await host.SendAsync(HttpMethod.Put, Stay, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("PUT", Stay)]
    [InlineData("DELETE", Stay)]
    [InlineData("PUT", Term)]
    [InlineData("DELETE", Term)]
    public async Task NoneOfItIsReachableWithoutAToken(string method, string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
