using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Validation;
using Gostio.Services.News;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.News;

public sealed class NewsReadingTests : IAsyncLifetime
{
    private const string Route = "/api/news";

    private readonly StubNews news = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services => services.AddSingleton<INewsService>(news));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest, Route)]
    [InlineData(RoleNames.Host, Route)]
    [InlineData(RoleNames.Administrator, Route)]
    [InlineData(RoleNames.Guest, $"{Route}/3")]
    [InlineData(RoleNames.Guest, $"{Route}/3/image")]
    public async Task ReadingIsOpenToAnySignedInAccount(string role, string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task ThePictureComesBackUnderTheTypeItIsStoredWith()
    {
        var response = await host.SendAsync(HttpMethod.Get, $"{Route}/3/image", RoleNames.Guest);

        Assert.Equal(ImageRules.Jpeg, response.Content.Headers.ContentType!.MediaType);
        Assert.Equal(StubNews.Bytes, await response.Content.ReadAsByteArrayAsync());
    }

    [Fact]
    public async Task TheListCarriesItsFiltersThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?title=storm&publishedFrom=2026-01-01T00:00:00Z"
                + "&publishedTo=2026-02-01T00:00:00Z&page=0&pageSize=5000",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("storm", news.LastSearch?.Title);
        Assert.Equal(
            new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            news.LastSearch?.PublishedFrom);
        Assert.Equal(
            new DateTime(2026, 2, 1, 0, 0, 0, DateTimeKind.Utc),
            news.LastSearch?.PublishedTo);
        Assert.Equal(1, news.LastSearch?.Page);
        Assert.Equal(PagedRequest.MaxPageSize, news.LastSearch?.PageSize);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
