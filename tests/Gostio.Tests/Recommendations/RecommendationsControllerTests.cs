using System.Net;
using System.Text.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Services.Recommendations;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Recommendations;

public sealed class RecommendationsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/recommendations";

    private readonly StubRecommendations recommendations = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IRecommendationService>(recommendations));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task TheSuggestionsAreOpenToAnySignedInAccount(string role)
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?target=Accommodations", role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheCatalogueAndThePageAreCarriedThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?target=Experiences&pageSize=5", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(SearchTarget.Experiences, recommendations.LastSearch?.Target);
        Assert.Equal(5, recommendations.LastSearch?.PageSize);
    }

    [Fact]
    public async Task TheAnswerCarriesTheCardTheScoreAndTheReasons()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?target=Accommodations", RoleNames.Guest);

        using var answer = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

        var first = answer.RootElement.GetProperty("items")[0];

        Assert.Equal(11, first.GetProperty("listingId").GetInt32());
        Assert.Equal("A place by the river", first.GetProperty("title").GetString());
        Assert.Equal(0.82, first.GetProperty("score").GetDouble());
        Assert.Equal(
            nameof(SearchTarget.Accommodations), first.GetProperty("target").GetString());

        var reason = Assert.Single(first.GetProperty("reasons").EnumerateArray());

        Assert.Equal(
            nameof(RecommendationReasonKind.City), reason.GetProperty("kind").GetString());

        Assert.Equal("Sarajevo", reason.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task TheSuggestionsAreNotReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, $"{Route}?target=Accommodations");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
