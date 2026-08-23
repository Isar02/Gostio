using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Gostio.API.Authentication;
using Gostio.API.Controllers;
using Gostio.API.Middleware;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Gostio.Tests.Crud;

// One controller stands for all of them: every managed table reaches the same
// generic base, so what is proved here about amenities holds for the rest.
// The service is a stub, because what is under test is the shape of the
// endpoint rather than the query behind it.
public sealed class CrudControllerTests : IAsyncLifetime
{
    private const string Route = "/api/amenities";

    private const string Key = "a-signing-key-long-enough-for-hmac-sha256";

    private const string Issuer = "Gostio.Tests";

    private const string Audience = "Gostio.Tests.Clients";

    private readonly StubAmenities amenities = new();

    private WebApplication app = null!;

    private HttpClient client = null!;

    public async Task InitializeAsync()
    {
        var builder = WebApplication.CreateBuilder();

        builder.Logging.ClearProviders();
        builder.WebHost.UseTestServer();

        builder.Services
            .AddControllers()
            .AddApplicationPart(typeof(AmenitiesController).Assembly);

        builder.Services.AddGostioValidationErrors();
        builder.Services.AddGostioAuthentication(new JwtSettings
        {
            Key = Key,
            Issuer = Issuer,
            Audience = Audience,
            ExpiresMinutes = 30,
        });

        builder.Services.AddSingleton<IUserSessionValidator, CurrentSessions>();
        builder.Services.AddSingleton<IAmenityService>(amenities);

        app = builder.Build();

        app.UseMiddleware<ExceptionHandlingMiddleware>();
        app.UseGostioStatusCodeErrors();
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapControllers();

        await app.StartAsync();

        client = app.GetTestClient();
    }

    public async Task DisposeAsync()
    {
        client.Dispose();

        await app.DisposeAsync();
    }

    [Fact]
    public async Task ReadingIsOpenToAnySignedInAccount()
    {
        var response = await SendAsync(HttpMethod.Get, Route, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var page = await response.Content.ReadFromJsonAsync<PagedResult<LookupResponse>>();

        Assert.Equal(["Wi-Fi"], page!.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ReadingWithoutATokenIsRefused()
    {
        var response = await SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // The bounds live in the request, and the query string is where a client
    // would go around them.
    [Fact]
    public async Task TheQueryStringReachesTheSearchRequestThroughItsBounds()
    {
        var response = await SendAsync(
            HttpMethod.Get, $"{Route}?name=fi&page=0&pageSize=5000", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("fi", amenities.LastSearch!.Name);
        Assert.Equal(1, amenities.LastSearch.Page);
        Assert.Equal(PagedRequest.MaxPageSize, amenities.LastSearch.PageSize);
    }

    [Fact]
    public async Task AGuestMayNotWrite()
    {
        var response = await SendAsync(
            HttpMethod.Post, Route, RoleNames.Guest, new LookupUpsertRequest { Name = "Sauna" });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Null(amenities.LastWrite);
    }

    [Fact]
    public async Task AnAdministratorCreatesARowAndIsToldWhereItIs()
    {
        var response = await SendAsync(
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
        var response = await SendAsync(
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
        var response = await SendAsync(HttpMethod.Delete, $"{Route}/4", RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        Assert.Equal(4, amenities.DeletedId);
    }

    [Fact]
    public async Task ANameOfNothingButSpacesIsRefusedInTheSharedShape()
    {
        var response = await SendAsync(
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

    private Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string path,
        string? role = null,
        object? body = null)
    {
        var request = new HttpRequestMessage(method, path);

        if (role is not null)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", TokenFor(role));
        }

        if (body is not null)
        {
            request.Content = JsonContent.Create(body);
        }

        return client.SendAsync(request);
    }

    private static string TokenFor(string role) =>
        new JwtTokenService(new JwtSettings
        {
            Key = Key,
            Issuer = Issuer,
            Audience = Audience,
            ExpiresMinutes = 30,
        }).Issue(new TokenSubject(42, "probe", "probe@example.com", 1, [role])).Value;

    private sealed class CurrentSessions : IUserSessionValidator
    {
        public Task<bool> IsCurrentAsync(
            int userId,
            int tokenVersion,
            CancellationToken cancellationToken) => Task.FromResult(true);
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
