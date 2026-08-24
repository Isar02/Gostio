using Gostio.Model.Authorization;
using Gostio.Services.Authentication;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// A host with a listing, and the service calls that reach it as somebody. The
// photo, amenity and availability suites all stand on that same ground, and
// what an accommodation and an experience answer differently is below it.
public abstract class ListingWorkspace(DatabaseFixture fixture)
{
    protected DatabaseFixture Fixture { get; } = fixture;

    public static ICurrentUser Caller(int userId, params string[] roles) =>
        new SignedInUser(userId, roles);

    public abstract Task<(int Host, int Listing)> AListingAsync(string password);

    public abstract Task WithdrawAsync(int host, int listing);

    public Task<TResult> AsHostAsync<TService, TResult>(
        int host,
        Func<TService, Task<TResult>> work)
        where TService : notnull =>
        AsAsync(Caller(host, RoleNames.Host), work);

    public Task AsHostAsync<TService>(int host, Func<TService, Task> work)
        where TService : notnull =>
        AsAsync(Caller(host, RoleNames.Host), work);

    public async Task<TResult> AsAsync<TService, TResult>(
        ICurrentUser caller,
        Func<TService, Task<TResult>> work,
        params IInterceptor[] interceptors)
        where TService : notnull
    {
        await using var services = Fixture.BuildServices(caller, interceptors);

        return await work(services.GetRequiredService<TService>());
    }

    public async Task AsAsync<TService>(
        ICurrentUser caller,
        Func<TService, Task> work,
        params IInterceptor[] interceptors)
        where TService : notnull
    {
        await using var services = Fixture.BuildServices(caller, interceptors);

        await work(services.GetRequiredService<TService>());
    }
}
