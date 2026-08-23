using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Lookups;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Crud;

// One controller stands for all of them: every managed table reaches the same
// generic base, so what is proved here about amenities holds for the rest.
public sealed class CrudControllerTests : IAsyncLifetime
{
    private const string Route = "/api/amenities";

    private readonly StubAmenities amenities = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IAmenityService>(amenities));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Fact]
    public async Task ReadingIsOpenToAnySignedInAccount()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var page = await response.Content.ReadFromJsonAsync<PagedResult<LookupResponse>>();

        Assert.Equal(["Wi-Fi"], page!.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ReadingWithoutATokenIsRefused()
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
            HttpMethod.Get, $"{Route}?name=fi&page=0&pageSize=5000", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("fi", amenities.LastSearch!.Name);
        Assert.Equal(1, amenities.LastSearch.Page);
        Assert.Equal(PagedRequest.MaxPageSize, amenities.LastSearch.PageSize);
    }

    [Fact]
    public async Task AGuestMayNotWrite()
    {
        var response = await host.SendAsync(
            HttpMethod.Post, Route, RoleNames.Guest, new LookupUpsertRequest { Name = "Sauna" });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Null(amenities.LastWrite);
    }

    [Fact]
    public async Task AnAdministratorCreatesARowAndIsToldWhereItIs()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Administrator,
            new LookupUpsertRequest { Name = "Sauna" });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal($"{Route}/7", response.Headers.Location!.AbsolutePath);
        Assert.Equal("Sauna", amenities.LastWrite);

        var created = await response.Content.ReadFromJsonAsync<LookupResponse>();

        Assert.Equal(7, created!.Id);
    }

    [Fact]
    public async Task AnAdministratorRenamesARow()
    {
        var response = await host.SendAsync(
            HttpMethod.Put,
            $"{Route}/3",
            RoleNames.Administrator,
            new LookupUpsertRequest { Name = "Steam room" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, amenities.UpdatedId);
        Assert.Equal("Steam room", amenities.LastWrite);
    }

    [Fact]
    public async Task AnAdministratorDeletesARowAndGetsNoBody()
    {
        var response = await host.SendAsync(
            HttpMethod.Delete, $"{Route}/4", RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(4, amenities.DeletedId);
    }

    [Fact]
    public async Task ANameOfNothingButSpacesIsRefusedInTheSharedShape()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Administrator,
            new LookupUpsertRequest { Name = "   " });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(amenities.LastWrite);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Equal(ValidationException.DefaultMessage, body!.Message);
        Assert.Contains(nameof(LookupUpsertRequest.Name), body.Errors!.Keys);
    }

    private sealed class StubAmenities : IAmenityService
    {
        public LookupSearchRequest? LastSearch { get; private set; }

        public string? LastWrite { get; private set; }

        public int? UpdatedId { get; private set; }

        public int? DeletedId { get; private set; }

        public Task<PagedResult<LookupResponse>> SearchAsync(
            LookupSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<LookupResponse>
            {
                Items = [Row(1, "Wi-Fi")],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<LookupResponse> GetAsync(int id, CancellationToken cancellationToken) =>
            Task.FromResult(Row(id, "Wi-Fi"));

        public Task<LookupResponse> CreateAsync(
            LookupUpsertRequest request,
            CancellationToken cancellationToken)
        {
            LastWrite = request.Name;

            return Task.FromResult(Row(7, request.Name));
        }

        public Task<LookupResponse> UpdateAsync(
            int id,
            LookupUpsertRequest request,
            CancellationToken cancellationToken)
        {
            UpdatedId = id;
            LastWrite = request.Name;

            return Task.FromResult(Row(id, request.Name));
        }

        public Task DeleteAsync(int id, CancellationToken cancellationToken)
        {
            DeletedId = id;

            return Task.CompletedTask;
        }

        private static LookupResponse Row(int id, string name) => new() { Id = id, Name = name };
    }
}
