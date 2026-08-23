using Gostio.Model.Authorization;
using Gostio.Services.Authentication;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// A host with a listing, and the service calls that reach it as somebody. The
// photo, amenity and availability suites all stand on that same ground.
internal sealed class ListingWorkspace(DatabaseFixture fixture)
{
    public static ICurrentUser Caller(int userId, params string[] roles) =>
        new SignedInUser(userId, roles);

    public async Task<ListingReferences> ReferencesAsync() =>
        new(
            await fixture.EnsureCityAsync("Sarajevo"),
            await fixture.EnsureAccommodationTypeAsync("Apartment"),
            await fixture.EnsureAccommodationCategoryAsync("City break"));

    public async Task<(int Host, int Listing)> AListingAsync(string password)
    {
        var host = await fixture.AddUserAsync(password, RoleNames.Host);

        return (host, await CreateAsync(host, $"A listing {Guid.NewGuid():N}"));
    }

    public async Task<int> CreateAsync(int host, string title)
    {
        var listing = ListingRequests.New(await ReferencesAsync(), title);

        var created = await AsHostAsync(
            host, (IAccommodationService listings) => listings.CreateAsync(listing, default));

        return created.Id;
    }

    public async Task WithdrawAsync(int host, int listing)
    {
        var withdrawn = ListingRequests.Edit(
            await ReferencesAsync(), "Taken off the market", isActive: false);

        await AsHostAsync(
            host,
            (IAccommodationService listings) => listings.UpdateAsync(listing, withdrawn, default));
    }

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
        await using var services = fixture.BuildServices(caller, interceptors);

        return await work(services.GetRequiredService<TService>());
    }

    public async Task AsAsync<TService>(
        ICurrentUser caller,
        Func<TService, Task> work,
        params IInterceptor[] interceptors)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(caller, interceptors);

        await work(services.GetRequiredService<TService>());
    }
}
