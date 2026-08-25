using System.Net;
using Gostio.Model.Authorization;
using Gostio.Services.Reviews;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Reviews;

public sealed class ReviewsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/reviews";

    private readonly StubReviews reviews = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IReviewService>(reviews));

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
    public async Task TheListCarriesItsFiltersThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?accommodationId=3&experienceId=4&hostId=5&guestId=6"
                + "&minRating=2&maxRating=4&pageSize=7",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, reviews.LastSearch?.AccommodationId);
        Assert.Equal(4, reviews.LastSearch?.ExperienceId);
        Assert.Equal(5, reviews.LastSearch?.HostId);
        Assert.Equal(6, reviews.LastSearch?.GuestId);
        Assert.Equal(2, reviews.LastSearch?.MinRating);
        Assert.Equal(4, reviews.LastSearch?.MaxRating);
        Assert.Equal(7, reviews.LastSearch?.PageSize);
    }

    [Fact]
    public async Task ARatingFilterOutsideTheStarsIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?minRating=9", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(reviews.LastSearch);
    }

    [Fact]
    public async Task TheListIsNotReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
