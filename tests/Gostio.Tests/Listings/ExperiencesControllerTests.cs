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
public sealed class ExperiencesControllerTests : IAsyncLifetime
{
    private const string Route = "/api/experiences";

    private readonly StubExperiences experiences = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IExperienceService>(experiences));

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

    [Fact]
    public async Task TheQueryStringReachesTheSearchRequestThroughItsBounds()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?title=walk&cityId=3&maxDurationMinutes=180&maxPrice=50&page=0&pageSize=5000",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("walk", experiences.LastSearch!.Title);
        Assert.Equal(3, experiences.LastSearch.CityId);
        Assert.Equal(180, experiences.LastSearch.MaxDurationMinutes);
        Assert.Equal(50m, experiences.LastSearch.MaxPrice);
        Assert.Equal(1, experiences.LastSearch.Page);
        Assert.Equal(PagedRequest.MaxPageSize, experiences.LastSearch.PageSize);
    }

    [Fact]
    public async Task AnUpdateThatDoesNotSayWhetherTheListingIsPublishedIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Put, $"{Route}/5", RoleNames.Host, Body(isActive: null));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Contains(nameof(ExperienceUpdateRequest.IsActive), body!.Errors!.Keys);
    }

    private static object? BodyFor(string method) => method switch
    {
        "POST" or "PUT" => Body(isActive: true),
        _ => null,
    };

    private static object Body(bool? isActive) => new
    {
        title = "A walk through the old town",
        description = "A walk through the old town, described at the length a listing needs.",
        experienceCategoryId = 1,
        cityId = 1,
        meetingPoint = "Sebilj",
        latitude = 43.8593m,
        longitude = 18.4310m,
        durationMinutes = 120,
        pricePerPerson = 40m,
        isActive,
    };

    private sealed class StubExperiences : IExperienceService
    {
        public ExperienceSearchRequest? LastSearch { get; private set; }

        public Task<PagedResult<ExperienceResponse>> SearchAsync(
            ExperienceSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<ExperienceResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<ExperienceResponse> GetAsync(int id, CancellationToken cancellationToken) =>
            Task.FromResult(Row(id));

        public Task<ExperienceResponse> CreateAsync(
            ExperienceCreateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(9));

        public Task<ExperienceResponse> UpdateAsync(
            int id,
            ExperienceUpdateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(id));

        public Task DeleteAsync(int id, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        private static ExperienceResponse Row(int id) => new()
        {
            Id = id,
            HostId = 42,
            HostName = "Lamija Hadžić",
            Title = "A walk through the old town",
            Description = "A walk through the old town, described at the length a listing needs.",
            ExperienceCategoryId = 1,
            ExperienceCategoryName = "Walking tour",
            CityId = 1,
            CityName = "Sarajevo",
            CountryName = "Bosnia and Herzegovina",
            MeetingPoint = "Sebilj",
            Latitude = 43.8593m,
            Longitude = 18.4310m,
            DurationMinutes = 120,
            PricePerPerson = 40m,
            IsActive = true,
            CoverPhotoId = null,
            AverageRating = 4.5m,
            ReviewCount = 2,
            IsFavorite = false,
            CreatedAt = DateTime.UtcNow,
        };
    }
}
