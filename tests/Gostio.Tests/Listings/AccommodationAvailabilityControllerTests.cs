using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// The calendar follows the listing: anybody signed in may read it, and only a
// host or an administrator may add and remove a range. Whose listing it is
// stays with the service.
public sealed class AccommodationAvailabilityControllerTests : IAsyncLifetime
{
    private const string Route = "/api/accommodations/7/availability";

    private readonly StubRanges ranges = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IAccommodationAvailabilityService>(ranges));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(Route)]
    [InlineData($"{Route}/3")]
    public async Task ReadingIsOpenToAnySignedInAccount(string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("POST", Route)]
    [InlineData("DELETE", $"{Route}/3")]
    public async Task WritingIsClosedToAGuest(string method, string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(method));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData(RoleNames.Host, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Host, "DELETE", $"{Route}/3", HttpStatusCode.NoContent)]
    [InlineData(RoleNames.Administrator, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Administrator, "DELETE", $"{Route}/3", HttpStatusCode.NoContent)]
    public async Task AHostAndAnAdministratorBothReachTheWrites(
        string role,
        string method,
        string path,
        HttpStatusCode expected)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, role, BodyFor(method));

        Assert.Equal(expected, response.StatusCode);
    }

    [Fact]
    public async Task TheRangeAndTheListingBothReachTheService()
    {
        await host.SendAsync(HttpMethod.Post, Route, RoleNames.Host, Body());

        Assert.Equal(new DateOnly(2026, 9, 1), ranges.LastRequest!.StartDate);
        Assert.Equal(new DateOnly(2026, 9, 7), ranges.LastRequest.EndDate);
        Assert.False(ranges.LastRequest.IsAvailable);
        Assert.Equal(7, ranges.LastAccommodationId);
    }

    [Fact]
    public async Task ARangeThatSaysNothingAboutBookingIsRefusedBeforeTheService()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Host,
            new AccommodationAvailabilityRequest
            {
                StartDate = new DateOnly(2026, 9, 1),
                EndDate = new DateOnly(2026, 9, 7),
            });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(ranges.LastRequest);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task TheQueryStringReachesThePageThroughItsBounds()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?page=0&pageSize=5000", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, ranges.LastSearch!.Page);
        Assert.Equal(PagedRequest.MaxPageSize, ranges.LastSearch.PageSize);
    }

    [Fact]
    public async Task TheWindowReachesTheServiceFromTheQueryString()
    {
        await host.SendAsync(
            HttpMethod.Get, $"{Route}?from=2026-09-01&to=2026-09-30", RoleNames.Guest);

        Assert.Equal(new DateOnly(2026, 9, 1), ranges.LastSearch!.From);
        Assert.Equal(new DateOnly(2026, 9, 30), ranges.LastSearch.To);
    }

    private static object? BodyFor(string method) => method == "POST" ? Body() : null;

    private static AccommodationAvailabilityRequest Body() => new()
    {
        StartDate = new DateOnly(2026, 9, 1),
        EndDate = new DateOnly(2026, 9, 7),
        IsAvailable = false,
    };

    private sealed class StubRanges : IAccommodationAvailabilityService
    {
        public AccommodationAvailabilitySearchRequest? LastSearch { get; private set; }

        public AccommodationAvailabilityRequest? LastRequest { get; private set; }

        public int? LastAccommodationId { get; private set; }

        public Task<PagedResult<AccommodationAvailabilityResponse>> SearchAsync(
            int accommodationId,
            AccommodationAvailabilitySearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<AccommodationAvailabilityResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<AccommodationAvailabilityResponse> GetAsync(
            int accommodationId,
            int availabilityId,
            CancellationToken cancellationToken) => Task.FromResult(Row(availabilityId));

        public Task<AccommodationAvailabilityResponse> AddAsync(
            int accommodationId,
            AccommodationAvailabilityRequest request,
            CancellationToken cancellationToken)
        {
            LastAccommodationId = accommodationId;
            LastRequest = request;

            return Task.FromResult(Row(9));
        }

        public Task DeleteAsync(
            int accommodationId,
            int availabilityId,
            CancellationToken cancellationToken) => Task.CompletedTask;

        private static AccommodationAvailabilityResponse Row(int id) => new()
        {
            Id = id,
            AccommodationId = 7,
            StartDate = new DateOnly(2026, 9, 1),
            EndDate = new DateOnly(2026, 9, 7),
            IsAvailable = false,
            PriceOverride = null,
        };
    }
}
