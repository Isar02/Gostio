using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// The slots follow the experience: anybody signed in may look, and only a host
// or an administrator may write. Whose experience it is, is left to the service.
public sealed class ExperienceSlotsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/experiences/7/slots";

    private readonly StubSlots slots = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IExperienceSlotService>(slots));

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
    [InlineData("PUT", $"{Route}/3")]
    [InlineData("DELETE", $"{Route}/3")]
    public async Task WritingIsClosedToAGuest(string method, string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(method));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData(RoleNames.Host, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Host, "PUT", $"{Route}/3", HttpStatusCode.OK)]
    [InlineData(RoleNames.Host, "DELETE", $"{Route}/3", HttpStatusCode.NoContent)]
    [InlineData(RoleNames.Administrator, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Administrator, "PUT", $"{Route}/3", HttpStatusCode.OK)]
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
            $"{Route}?from=2026-09-01T00:00:00Z&isActive=true&page=0&pageSize=5000",
            RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(true, slots.LastSearch!.IsActive);
        Assert.Equal(1, slots.LastSearch.Page);
        Assert.Equal(PagedRequest.MaxPageSize, slots.LastSearch.PageSize);
    }

    // Left out of the body they would close the term or empty it, so neither is
    // a field an update can default.
    [Theory]
    [InlineData(null, true, nameof(ExperienceSlotUpdateRequest.Capacity))]
    [InlineData(8, null, nameof(ExperienceSlotUpdateRequest.IsActive))]
    public async Task AnUpdateMissingEitherAnswerIsRefused(
        int? capacity,
        bool? isActive,
        string field)
    {
        var response = await host.SendAsync(
            HttpMethod.Put, $"{Route}/3", RoleNames.Host, new { capacity, isActive });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Contains(field, body!.Errors!.Keys);
    }

    [Fact]
    public async Task ASlotTakingNobodyIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Host,
            new { startTime = "2026-09-01T10:00:00Z", capacity = 0 });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Contains(nameof(ExperienceSlotCreateRequest.Capacity), body!.Errors!.Keys);
    }

    private static object? BodyFor(string method) => method switch
    {
        "POST" => new { startTime = "2026-09-01T10:00:00Z", capacity = 8 },
        "PUT" => new { capacity = 8, isActive = true },
        _ => null,
    };

    private sealed class StubSlots : IExperienceSlotService
    {
        public ExperienceSlotSearchRequest? LastSearch { get; private set; }

        public Task<PagedResult<ExperienceSlotResponse>> SearchAsync(
            int experienceId,
            ExperienceSlotSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<ExperienceSlotResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<ExperienceSlotResponse> GetAsync(
            int experienceId,
            int slotId,
            CancellationToken cancellationToken) => Task.FromResult(Row(slotId));

        public Task<ExperienceSlotResponse> AddAsync(
            int experienceId,
            ExperienceSlotCreateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(9));

        public Task<ExperienceSlotResponse> UpdateAsync(
            int experienceId,
            int slotId,
            ExperienceSlotUpdateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(slotId));

        public Task DeleteAsync(
            int experienceId,
            int slotId,
            CancellationToken cancellationToken) => Task.CompletedTask;

        private static ExperienceSlotResponse Row(int id) => new()
        {
            Id = id,
            ExperienceId = 7,
            StartTime = new DateTime(2026, 9, 1, 10, 0, 0, DateTimeKind.Utc),
            EndTime = new DateTime(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc),
            DurationMinutes = 120,
            Capacity = 8,
            RemainingCapacity = 6,
            IsActive = true,
        };
    }
}
