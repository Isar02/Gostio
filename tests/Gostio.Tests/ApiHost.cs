using System.Net.Http.Headers;
using System.Net.Http.Json;
using Gostio.API.Authentication;
using Gostio.API.Controllers;
using Gostio.API.Middleware;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Gostio.Tests;

// The real controllers, the real bearer registration and the real error shape,
// with only the services behind them stubbed. What a test on this host is
// asking about is the endpoint rather than the query.
internal sealed class ApiHost : IAsyncDisposable
{
    private const string Key = "a-signing-key-long-enough-for-hmac-sha256";

    private const string Issuer = "Gostio.Tests";

    private const string Audience = "Gostio.Tests.Clients";

    private readonly WebApplication app;

    private ApiHost(WebApplication app)
    {
        this.app = app;

        Client = app.GetTestClient();
    }

    public HttpClient Client { get; }

    public static async Task<ApiHost> StartAsync(Action<IServiceCollection> stubs)
    {
        var builder = WebApplication.CreateBuilder();

        builder.Logging.ClearProviders();
        builder.WebHost.UseTestServer();

        builder.Services
            .AddControllers()
            .AddApplicationPart(typeof(AmenitiesController).Assembly)
            .AddGostioJson();

        builder.Services.AddGostioValidationErrors();
        builder.Services.AddGostioAuthentication(Settings());
        builder.Services.AddSingleton<IUserSessionValidator, CurrentSessions>();

        stubs(builder.Services);

        var app = builder.Build();

        app.UseMiddleware<ExceptionHandlingMiddleware>();
        app.UseGostioStatusCodeErrors();
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapControllers();

        await app.StartAsync();

        return new ApiHost(app);
    }

    public Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string path,
        string? role = null,
        object? body = null) =>
        SendAsync(method, path, role is null ? [] : [role], body);

    public Task<HttpResponseMessage> SendAsync(
        HttpMethod method,
        string path,
        string[] roles,
        object? body = null)
    {
        var request = new HttpRequestMessage(method, path);

        if (roles.Length > 0)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue(
                "Bearer", TokenFor(roles));
        }

        if (body is not null)
        {
            // An upload arrives as content already; everything else is JSON.
            request.Content = body as HttpContent ?? JsonContent.Create(body);
        }

        return Client.SendAsync(request);
    }

    public async ValueTask DisposeAsync()
    {
        Client.Dispose();

        await app.DisposeAsync();
    }

    private static string TokenFor(string[] roles) =>
        new JwtTokenService(Settings())
            .Issue(new TokenSubject(42, "probe", "probe@example.com", 1, roles))
            .Value;

    private static JwtSettings Settings() =>
        new()
        {
            Key = Key,
            Issuer = Issuer,
            Audience = Audience,
            ExpiresMinutes = 30,
        };

    private sealed class CurrentSessions : IUserSessionValidator
    {
        public Task<bool> IsCurrentAsync(
            int userId,
            int tokenVersion,
            CancellationToken cancellationToken) => Task.FromResult(true);
    }
}
