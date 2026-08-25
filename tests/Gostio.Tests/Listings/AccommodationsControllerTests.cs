using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// Reading is open and writing is not, and the row-level half of the rule sits
// in the service. What this asks about is the half an attribute can state.
public sealed class AccommodationsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/accommodations";

    private readonly StubAccommodations accommodations = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IAccommodationService>(accommodations));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(Route)]
    [InlineData($"{Route}/5")]
    public async Task ReadingIsOpenToAnySignedInAccount(string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("POST", Route)]
    [InlineData("PUT", $"{Route}/5")]
    [InlineData("DELETE", $"{Route}/5")]
    public async Task WritingIsClosedToAGuest(string method, string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(method));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData(RoleNames.Host, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Host, "PUT", $"{Route}/5", HttpStatusCode.OK)]
    [InlineData(RoleNames.Host, "DELETE", $"{Route}/5", HttpStatusCode.NoContent)]
    [InlineData(RoleNames.Administrator, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Administrator, "PUT", $"{Route}/5", HttpStatusCode.OK)]
    [InlineData(RoleNames.Administrator, "DELETE", $"{Route}/5", HttpStatusCode.NoContent)]
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
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // The bounds live in the request, and the query string is where a client
    // would go around them.
    [Fact]
    public async Task TheQueryStringReachesTheSearchRequestThroughItsBounds()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?title=loft&cityId=3&minGuests=4&maxPrice=120&page=0&pageSize=5000",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("loft", accommodations.LastSearch!.Title);
        Assert.Equal(3, accommodations.LastSearch.CityId);
        Assert.Equal(4, accommodations.LastSearch.MinGuests);
        Assert.Equal(120m, accommodations.LastSearch.MaxPrice);
        Assert.Equal(1, accommodations.LastSearch.Page);
        Assert.Equal(PagedRequest.MaxPageSize, accommodations.LastSearch.PageSize);
    }

    // Left out of the body it would silently withdraw the listing, so it is the
    // one field an update cannot default.
    [Fact]
    public async Task AnUpdateThatDoesNotSayWhetherTheListingIsPublishedIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Put, $"{Route}/5", RoleNames.Host, Body(isActive: null));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Contains(nameof(AccommodationUpdateRequest.IsActive), body!.Errors!.Keys);
    }

    private static object? BodyFor(string method) => method switch
    {
        "POST" or "PUT" => Body(isActive: true),
        _ => null,
    };

    private static object Body(bool? isActive) => new
    {
        title = "A loft over the river",
        description = "A place to stay, described at the length a listing needs.",
        accommodationTypeId = 1,
        accommodationCategoryId = 1,
        cityId = 1,
        address = "Ferhadija 1",
        latitude = 43.8563m,
        longitude = 18.4131m,
        maxGuests = 4,
        bedrooms = 2,
        bathrooms = 1,
        pricePerNight = 100m,
        cleaningFee = 15m,
        isActive,
    };

    private sealed class StubAccommodations : IAccommodationService
    {
        public AccommodationSearchRequest? LastSearch { get; private set; }

        public Task<PagedResult<AccommodationResponse>> SearchAsync(
            AccommodationSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<AccommodationResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<AccommodationResponse> GetAsync(int id, CancellationToken cancellationToken) =>
            Task.FromResult(Row(id));

        public Task<AccommodationResponse> CreateAsync(
            AccommodationCreateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(9));

        public Task<AccommodationResponse> UpdateAsync(
            int id,
            AccommodationUpdateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(id));

        public Task DeleteAsync(int id, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        private static AccommodationResponse Row(int id) => new()
        {
            Id = id,
            HostId = 42,
            HostName = "Lamija Hadžić",
            Title = "A loft over the river",
            Description = "A place to stay, described at the length a listing needs.",
            AccommodationTypeId = 1,
            AccommodationTypeName = "Apartment",
            AccommodationCategoryId = 1,
            AccommodationCategoryName = "City break",
            CityId = 1,
            CityName = "Sarajevo",
            CountryName = "Bosnia and Herzegovina",
            Address = "Ferhadija 1",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            MaxGuests = 4,
            Bedrooms = 2,
            Bathrooms = 1,
            PricePerNight = 100m,
            CleaningFee = 15m,
            IsActive = true,
            CoverPhotoId = null,
            AverageRating = 4.5m,
            ReviewCount = 2,
            CreatedAt = DateTime.UtcNow,
        };
    }
}
