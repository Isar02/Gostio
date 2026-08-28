using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Users;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Users;

// Everything under an id belongs to an administrator except the picture, and
// what sits under `me` belongs to whoever is signed in, so the whole
// authorization surface is written out. An attribute quietly left off one of
// them opens a list of people to anybody holding a token.
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
    [InlineData("PUT", "/api/users/5/image")]
    [InlineData("DELETE", "/api/users/5/image")]
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
    [InlineData("PUT", "/api/users/5/image", HttpStatusCode.OK)]
    [InlineData("DELETE", "/api/users/5/image", HttpStatusCode.NoContent)]
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
    [InlineData("GET", "/api/users/me", HttpStatusCode.OK)]
    [InlineData("PUT", "/api/users/me", HttpStatusCode.OK)]
    [InlineData("PUT", "/api/users/me/image", HttpStatusCode.OK)]
    [InlineData("DELETE", "/api/users/me/image", HttpStatusCode.NoContent)]
    public async Task AnAccountReachesItsOwnProfileWhateverRoleItHolds(
        string method,
        string path,
        HttpStatusCode expected)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(path));

        Assert.Equal(expected, response.StatusCode);
    }

    // A host's picture stands beside their listings and a participant's beside
    // their messages, so the one read under an id is open to anybody signed in.
    [Fact]
    public async Task APictureUnderAnIdIsReadByAnybodySignedIn()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, "/api/users/5/image", RoleNames.Guest);

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
        "/api/users/5/image" or "/api/users/me/image" => UserImages.Form(),
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
}
