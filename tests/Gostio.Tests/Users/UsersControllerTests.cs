using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Users;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Users;

// Everything under an id belongs to an administrator and the two under `me`
// belong to whoever is signed in, so the whole authorization surface is written
// out. An attribute quietly left off one of them opens a list of people to
// anybody holding a token.
public sealed class UsersControllerTests : IAsyncLifetime
{
    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IUserService, StubUsers>());

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData("GET", "/api/users")]
    [InlineData("POST", "/api/users")]
    [InlineData("GET", "/api/users/5")]
    [InlineData("PUT", "/api/users/5")]
    [InlineData("PUT", "/api/users/5/roles")]
    [InlineData("PUT", "/api/users/5/state")]
    [InlineData("DELETE", "/api/users/5")]
    public async Task WhatBelongsToAnAdministratorIsClosedToAGuest(string method, string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(path));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData("GET", "/api/users", HttpStatusCode.OK)]
    [InlineData("POST", "/api/users", HttpStatusCode.Created)]
    [InlineData("GET", "/api/users/5", HttpStatusCode.OK)]
    [InlineData("PUT", "/api/users/5", HttpStatusCode.OK)]
    [InlineData("PUT", "/api/users/5/roles", HttpStatusCode.OK)]
    [InlineData("PUT", "/api/users/5/state", HttpStatusCode.OK)]
    [InlineData("DELETE", "/api/users/5", HttpStatusCode.NoContent)]
    public async Task AnAdministratorReachesAllOfIt(
        string method,
        string path,
        HttpStatusCode expected)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Administrator, BodyFor(path));

        Assert.Equal(expected, response.StatusCode);
    }

    [Theory]
    [InlineData("GET", "/api/users/me")]
    [InlineData("PUT", "/api/users/me")]
    public async Task AnAccountReachesItsOwnProfileWhateverRoleItHolds(
        string method,
        string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(path));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/users")]
    [InlineData("/api/users/5/roles")]
    public async Task AnExplicitlyNullRoleListIsAFourHundred(string path)
    {
        var method = path.EndsWith("roles", StringComparison.Ordinal)
            ? HttpMethod.Put
            : HttpMethod.Post;

        var response = await host.SendAsync(
            method, path, RoleNames.Administrator, NullRolesBodyFor(path));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Contains(nameof(UserRolesRequest.Roles), body!.Errors!.Keys);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, "/api/users/5");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static object NullRolesBodyFor(string path) => path switch
    {
        "/api/users" => new
        {
            firstName = "Amina",
            lastName = "Kovačević",
            username = "amina.kovacevic",
            email = "amina.kovacevic@example.com",
            password = "a-long-enough-password",
            confirmPassword = "a-long-enough-password",
            roles = (string[]?)null,
        },
        _ => new { roles = (string[]?)null },
    };

    private static object? BodyFor(string path) => path switch
    {
        "/api/users" => new UserCreateRequest
        {
            FirstName = "Amina",
            LastName = "Kovačević",
            Username = "amina.kovacevic",
            Email = "amina.kovacevic@example.com",
            Password = "a-long-enough-password",
            ConfirmPassword = "a-long-enough-password",
            Roles = [RoleNames.Guest],
        },
        "/api/users/5/roles" => new UserRolesRequest { Roles = [RoleNames.Guest] },
        "/api/users/5/state" => new UserStateRequest { IsActive = false },
        "/api/users/5" or "/api/users/me" => new UserUpdateRequest
        {
            FirstName = "Amina",
            LastName = "Kovačević",
            Email = "amina.kovacevic@example.com",
        },
        _ => null,
    };

    private sealed class StubUsers : IUserService
    {
        public Task<PagedResult<UserResponse>> SearchAsync(
            UserSearchRequest search,
            CancellationToken cancellationToken) =>
            Task.FromResult(new PagedResult<UserResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });

        public Task<UserResponse> GetAsync(int id, CancellationToken cancellationToken) =>
            Task.FromResult(Row(id));

        public Task<UserResponse> GetMineAsync(CancellationToken cancellationToken) =>
            Task.FromResult(Row(1));

        public Task<UserResponse> UpdateMineAsync(
            UserUpdateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(1));

        public Task<UserResponse> CreateAsync(
            UserCreateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(9));

        public Task<UserResponse> UpdateAsync(
            int id,
            UserUpdateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(id));

        public Task<UserResponse> SetRolesAsync(
            int id,
            UserRolesRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(id));

        public Task<UserResponse> SetStateAsync(
            int id,
            UserStateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(id));

        public Task DeleteAsync(int id, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        private static UserResponse Row(int id) => new()
        {
            Id = id,
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
