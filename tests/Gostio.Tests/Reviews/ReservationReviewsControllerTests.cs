using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Services.Reviews;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Reviews;

public sealed class ReservationReviewsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/reservations/9/review";

    private readonly StubReviews reviews = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IReviewService>(reviews));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Fact]
    public async Task ReadingOneNamesTheBookingItHangsOff()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(9, reviews.LastRead);
    }

    [Fact]
    public async Task WritingOneAnswersWhereItCanBeReadBack()
    {
        var response = await host.SendAsync(
            HttpMethod.Post, Route, RoleNames.Guest, Written(4, "Quiet and clean."));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal(Route, response.Headers.Location?.AbsolutePath);
        Assert.Equal(9, reviews.LastWritten);
        Assert.Equal(4, reviews.LastRequest?.Rating);
        Assert.Equal("Quiet and clean.", reviews.LastRequest?.Comment);
    }

    [Fact]
    public async Task ChangingOneCarriesTheNewRatingThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Put, Route, RoleNames.Guest, Written(2, "The heating failed."));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(9, reviews.LastUpdated);
        Assert.Equal(2, reviews.LastRequest?.Rating);
    }

    [Fact]
    public async Task TakingOneDownAnswersWithNothing()
    {
        var response = await host.SendAsync(HttpMethod.Delete, Route, RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(9, reviews.LastDeleted);
    }

    [Theory]
    [InlineData(null)]
    [InlineData(0)]
    [InlineData(6)]
    public async Task ARatingOutsideTheStarsNeverReachesTheService(int? rating)
    {
        var response = await host.SendAsync(
            HttpMethod.Post, Route, RoleNames.Guest, Written(rating, null));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(reviews.LastWritten);
    }

    [Theory]
    [InlineData("GET")]
    [InlineData("POST")]
    [InlineData("PUT")]
    [InlineData("DELETE")]
    public async Task NoneOfItIsReachableWithoutAToken(string method)
    {
        var response = await host.SendAsync(new HttpMethod(method), Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static ReviewUpsertRequest Written(int? rating, string? comment) =>
        new() { Rating = rating, Comment = comment };
}
