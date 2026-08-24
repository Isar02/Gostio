using Gostio.Model.Authorization;
using Gostio.Services.Listings;

namespace Gostio.IntegrationTests;

internal sealed class ExperienceWorkspace(DatabaseFixture fixture) : ListingWorkspace(fixture)
{
    public async Task<ExperienceReferences> ReferencesAsync() =>
        new(
            await Fixture.EnsureCityAsync("Sarajevo"),
            await Fixture.EnsureExperienceCategoryAsync("Walking tour"));

    public override async Task<(int Host, int Listing)> AListingAsync(string password)
    {
        var host = await Fixture.AddUserAsync(password, RoleNames.Host);

        return (host, await CreateAsync(host, $"An experience {Guid.NewGuid():N}"));
    }

    public async Task<int> CreateAsync(int host, string title)
    {
        var experience = ExperienceRequests.New(await ReferencesAsync(), title);

        var created = await AsHostAsync(
            host, (IExperienceService experiences) => experiences.CreateAsync(experience, default));

        return created.Id;
    }

    public override async Task WithdrawAsync(int host, int listing)
    {
        var withdrawn = ExperienceRequests.Edit(
            await ReferencesAsync(), "No longer running", isActive: false);

        await AsHostAsync(
            host,
            (IExperienceService experiences) =>
                experiences.UpdateAsync(listing, withdrawn, default));
    }
}
