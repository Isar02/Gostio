using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using Gostio.API.Authentication;
using Gostio.API.Middleware;
using Gostio.Model.Authorization;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Gostio.Tests.Authentication;

// A host carrying the real bearer registration and one probe controller. The
// session validator is the only piece stubbed, because the alternative is a
// database, and what is under test here is the pipeline rather than the query.
public sealed class AuthenticationPipelineTests : IAsyncLifetime
{
    private const string Key = "a-signing-key-long-enough-for-hmac-sha256";

    private const string Issuer = "Gostio.Tests";

    private const string Audience = "Gostio.Tests.Clients";

    private readonly StubSessions sessions = new();

    private WebApplication app = null!;

    private HttpClient client = null!;

    public async Task InitializeAsync()
    {
        var builder = WebApplication.CreateBuilder();

        builder.Logging.ClearProviders();
        builder.WebHost.UseTestServer();

        builder.Services
            .AddControllers()
            .AddApplicationPart(typeof(SecuredProbeController).Assembly);

        builder.Services.AddGostioAuthentication(Settings());
        builder.Services.AddSingleton<IUserSessionValidator>(sessions);

        app = builder.Build();

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
    public async Task AnEndpointMarkedAnonymousAnswersWithoutTheToken()
    {
        var response = await GetAsync("/secured-probe/open");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task ARequestWithoutATokenIsRefusedInTheSharedShape()
    {
        var response = await GetAsync("/secured-probe/signed-in");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.NotNull(body);
        Assert.Equal("This request needs a signed in user.", body!.Message);
        Assert.False(string.IsNullOrWhiteSpace(body.TraceId));
    }

    // The fallback policy, and the reason a forgotten attribute is not a hole.
    [Fact]
    public async Task AnEndpointThatCarriesNoAttributeIsClosedAllTheSame()
    {
        var response = await GetAsync("/secured-probe/unattributed");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task TheCallerIsTakenFromTheTokenRatherThanTheRequest()
    {
        var response = await GetAsync("/secured-probe/signed-in", TokenFor(RoleNames.Guest));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("42", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task AnAdministratorReachesAnAdministratorEndpoint()
    {
        var response = await GetAsync(
            "/secured-probe/administrators", TokenFor(RoleNames.Administrator));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task AGuestIsTurnedAwayFromAnAdministratorEndpoint()
    {
        var response = await GetAsync("/secured-probe/administrators", TokenFor(RoleNames.Guest));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Equal("This account may not perform that action.", body!.Message);
    }

    [Fact]
    public async Task ATokenSignedWithAnotherKeyIsRefused()
    {
        var foreign = new JwtTokenService(Settings(key: "another-signing-key-just-as-long-as-the-real"))
            .Issue(SubjectWith(RoleNames.Administrator));

        var response = await GetAsync("/secured-probe/signed-in", foreign.Value);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // Expired one minute ago, which the five minutes of clock skew that bearer
    // tokens are validated with by default would wave straight through.
    [Fact]
    public async Task ATokenThatExpiredAMomentAgoIsRefused()
    {
        var response = await GetAsync("/secured-probe/signed-in", ExpiredToken());

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    // Signing out raises the version on the row, which is what this stands for.
    [Fact]
    public async Task ATokenFromASessionThatHasEndedIsRefused()
    {
        sessions.IsCurrent = false;

        var response = await GetAsync("/secured-probe/signed-in", TokenFor(RoleNames.Guest));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static JwtSettings Settings(string key = Key, int expiresMinutes = 30) =>
        new()
        {
            Key = key,
            Issuer = Issuer,
            Audience = Audience,
            ExpiresMinutes = expiresMinutes,
        };

    private static TokenSubject SubjectWith(params string[] roles) =>
        new(42, "probe", "probe@example.com", 1, roles);

    private static string TokenFor(params string[] roles) =>
        new JwtTokenService(Settings()).Issue(SubjectWith(roles)).Value;

    // Written out rather than issued, because a negative lifetime would put the
    // not-before after the expiry and be refused for that instead.
    private static string ExpiredToken()
    {
        var issuedAt = DateTime.UtcNow.AddMinutes(-10);

        return new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = Issuer,
            Audience = Audience,
            IssuedAt = issuedAt,
            NotBefore = issuedAt,
            Expires = DateTime.UtcNow.AddMinutes(-1),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Key)),
                JwtTokenService.SigningAlgorithm),
            Claims = new Dictionary<string, object>
            {
                [GostioClaimTypes.UserId] = 42,
                [GostioClaimTypes.TokenVersion] = 1,
            },
        });
    }

    private Task<HttpResponseMessage> GetAsync(string path, string? token = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, path);

        if (token is not null)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return client.SendAsync(request);
    }

    private sealed class StubSessions : IUserSessionValidator
    {
        public bool IsCurrent { get; set; } = true;

        public Task<bool> IsCurrentAsync(
            int userId,
            int tokenVersion,
            CancellationToken cancellationToken) => Task.FromResult(IsCurrent);
    }
}

[ApiController]
[Route("secured-probe")]
public sealed class SecuredProbeController : ControllerBase
{
    [AllowAnonymous]
    [HttpGet("open")]
    public IActionResult Open() => Ok("open");

    [Authorize]
    [HttpGet("signed-in")]
    public IActionResult SignedIn() => Ok(User.UserId());

    [Authorize(Roles = RoleNames.Administrator)]
    [HttpGet("administrators")]
    public IActionResult Administrators() => Ok("administrators");

    [HttpGet("unattributed")]
    public IActionResult Unattributed() => Ok("unattributed");
}
