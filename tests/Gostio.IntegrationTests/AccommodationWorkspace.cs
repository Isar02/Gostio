using Gostio.Model.Authorization;
using Gostio.Services.Listings;

namespace Gostio.IntegrationTests;

internal sealed class AccommodationWorkspace(DatabaseFixture fixture)
    : ListingWorkspace(fixture)
{
    public async Task<ListingReferences> ReferencesAsync() =>
        new(
            await Fixture.EnsureCityAsync("Sarajevo"),
            await Fixture.EnsureAccommodationTypeAsync("Apartment"),
            await Fixture.EnsureAccommodationCategoryAsync("City break"));

    public override async Task<(int Host, int Listing)> AListingAsync(string password)
    {
        var host = await Fixture.AddUserAsync(password, RoleNames.Host);

        return (host, await CreateAsync(host, $"A listing {Guid.NewGuid():N}"));
    }

    public async Task<int> CreateAsync(int host, string title)
    {
        var listing = ListingRequests.New(await ReferencesAsync(), title);

        var created = await AsHostAsync(
            host, (IAccommodationService listings) => listings.CreateAsync(listing, default));

        return created.Id;
    }

    public override async Task WithdrawAsync(int host, int listing)
    {
        var withdrawn = ListingRequests.Edit(
            await ReferencesAsync(), "Taken off the market", isActive: false);

        await AsHostAsync(
            host,
            (IAccommodationService listings) => listings.UpdateAsync(listing, withdrawn, default));
    }
}
