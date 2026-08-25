using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ListingFavoriteMarkTests(DatabaseFixture fixture)
{
    private readonly FavoriteWorkspace workspace = new(fixture);

    [Fact]
    public async Task AnAccommodationTheCallerKeptComesBackMarked()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);

        var card = await ReadAccommodationAsync(guest, listing);

        Assert.True(card.IsFavorite);
    }

    [Fact]
    public async Task AnExperienceIsMarkedTheSameWay()
    {
        var (_, listing) = await workspace.AnExperienceAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepExperienceAsync(guest, listing);

        var card = await ReadExperienceAsync(guest, listing);

        Assert.True(card.IsFavorite);
    }

    // The mark is one person's, so it has to be read off the caller rather than
    // off the listing: a mark that was the listing's would light up for
    // everybody the moment one guest kept it.
    [Fact]
    public async Task WhatOneGuestKeepsIsUnmarkedForAnother()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var keeper = await workspace.AGuestAsync();
        var stranger = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(keeper, listing);

        var card = await ReadAccommodationAsync(stranger, listing);

        Assert.False(card.IsFavorite);
    }

    [Fact]
    public async Task WhatOneGuestKeepsOnAnExperienceIsUnmarkedForAnother()
    {
        var (_, listing) = await workspace.AnExperienceAsync();
        var keeper = await workspace.AGuestAsync();
        var stranger = await workspace.AGuestAsync();

        await workspace.KeepExperienceAsync(keeper, listing);

        var card = await ReadExperienceAsync(stranger, listing);

        Assert.False(card.IsFavorite);
    }

    [Fact]
    public async Task ASearchCarriesTheMarkTheSingleReadDoes()
    {
        var (host, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);

        var found = await FoundAccommodationAsync(guest, host, listing);

        Assert.True(found.IsFavorite);
    }

    [Fact]
    public async Task DroppingAListingTakesTheMarkOffAgain()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);
        await workspace.DropAccommodationAsync(guest, listing);

        var card = await ReadAccommodationAsync(guest, listing);

        Assert.False(card.IsFavorite);
    }

    private Task<AccommodationResponse> ReadAccommodationAsync(int actor, int listing) =>
        AsGuestAsync(
            actor, (IAccommodationService service) => service.GetAsync(listing, default));

    private Task<ExperienceResponse> ReadExperienceAsync(int actor, int experience) =>
        AsGuestAsync(
            actor, (IExperienceService service) => service.GetAsync(experience, default));

    private async Task<AccommodationResponse> FoundAccommodationAsync(
        int actor,
        int host,
        int listing)
    {
        var page = await AsGuestAsync(
            actor,
            (IAccommodationService service) => service.SearchAsync(
                new AccommodationSearchRequest { HostId = host }, default));

        return page.Items.Single(item => item.Id == listing);
    }

    private async Task<TResult> AsGuestAsync<TService, TResult>(
        int actor,
        Func<TService, Task<TResult>> work)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, RoleNames.Guest));

        return await work(services.GetRequiredService<TService>());
    }
}
