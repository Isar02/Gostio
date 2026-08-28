using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Authentication;

public sealed class RegistrationEndpointTests : IAsyncLifetime
{
    private readonly StubAuth auth = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services => services.AddSingleton<IAuthService>(auth));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Fact]
    public async Task ARegistrationIsAnsweredWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Post, "/api/auth/register", body: Body());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // Sent the way a client that guessed the shape would send them. There is
    // nothing to bind them to, so they are dropped on the way in rather than
    // refused, and what comes back is a guest either way.
    [Fact]
    public async Task AskingForAdministratorInTheBodyChangesNothing()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            "/api/auth/register",
            body: Body([RoleNames.Administrator, RoleNames.Host]));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var registered = await response.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal([RoleNames.Guest], registered!.User.Roles);
        Assert.Equal("amina.kovacevic", auth.Registered!.Username);

        Assert.DoesNotContain(
            typeof(RegisterRequest).GetProperties(),
            property => property.Name.Contains("Role", StringComparison.OrdinalIgnoreCase));
    }

    private static object Body(string[]? roles = null) => roles is null
        ? new
        {
            firstName = "Amina",
            lastName = "Kovačević",
            username = "amina.kovacevic",
            email = "amina.kovacevic@example.com",
            password = "a-long-enough-password",
            confirmPassword = "a-long-enough-password",
        }
        : new
        {
            firstName = "Amina",
            lastName = "Kovačević",
            username = "amina.kovacevic",
            email = "amina.kovacevic@example.com",
            password = "a-long-enough-password",
            confirmPassword = "a-long-enough-password",
            roles,
        };

    private sealed class StubAuth : IAuthService
    {
        public RegisterRequest? Registered { get; private set; }

        public Task<AuthResponse> RegisterAsync(
            RegisterRequest request,
            CancellationToken cancellationToken)
        {
            Registered = request;

            return Task.FromResult(Issued());
        }

        public Task<AuthResponse> LoginAsync(
            LoginRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Issued());

        public Task<UserResponse> GetCurrentUserAsync(CancellationToken cancellationToken) =>
            Task.FromResult(Row());

        public Task<AuthResponse> ChangePasswordAsync(
            ChangePasswordRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Issued());

        public Task LogoutAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public Task ForgotPasswordAsync(
            ForgotPasswordRequest request,
            CancellationToken cancellationToken) => Task.CompletedTask;

        public Task ResetPasswordAsync(
            ResetPasswordRequest request,
            CancellationToken cancellationToken) => Task.CompletedTask;

        private static AuthResponse Issued() => new()
        {
            Token = "a-token",
            ExpiresAt = DateTime.UtcNow.AddMinutes(30),
            User = Row(),
        };

        private static UserResponse Row() => new()
        {
            Id = 1,
            FirstName = "Amina",
            LastName = "Kovačević",
            Username = "amina.kovacevic",
            Email = "amina.kovacevic@example.com",
            PhoneNumber = null,
            IsActive = true,
            Roles = [RoleNames.Guest],
            CreatedAt = DateTime.UtcNow,
        };
    }
}
