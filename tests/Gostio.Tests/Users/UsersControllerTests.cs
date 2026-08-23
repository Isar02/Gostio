using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Users;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Users;

// No two of these endpoints answer to the same rule, so the whole authorization
// surface is written out. An attribute quietly left off one of them opens a
// list of people to anybody holding a token.
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

    // Open to any signed in account at the endpoint, because whether the caller
    // may see this particular row is a question only the service can answer.
    [Theory]
    [InlineData("GET", "/api/users/5")]
    [InlineData("PUT", "/api/users/5")]
    public async Task TheOwnProfileEndpointsAreLeftToTheService(string method, string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(path));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, "/api/users/5");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

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
        "/api/users/5" => new UserUpdateRequest
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
