using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class FavoriteTests(DatabaseFixture fixture)
{
    private readonly FavoriteWorkspace workspace = new(fixture);

    [Fact]
    public async Task AKeptAccommodationComesBackAsACard()
    {
        var (host, listing) = await workspace.AnAccommodationAsync();
        var cover = await workspace.ACoverPhotoAsync(host, listing);
        var guest = await workspace.AGuestAsync();

        var kept = await workspace.KeepAccommodationAsync(guest, listing);

        Assert.Equal(listing, kept.AccommodationId);
        Assert.Null(kept.ExperienceId);
        Assert.Equal(cover, kept.CoverPhotoId);
        Assert.True(kept.IsListingActive);
        Assert.NotEmpty(kept.ListingTitle);
        Assert.NotEmpty(kept.CityName);
        Assert.NotEmpty(kept.CountryName);
        Assert.True(kept.Price > 0);
    }

    [Fact]
    public async Task AKeptExperienceComesBackTheSameWay()
    {
        var (_, listing) = await workspace.AnExperienceAsync();
        var guest = await workspace.AGuestAsync();

        var kept = await workspace.KeepExperienceAsync(guest, listing);

        Assert.Equal(listing, kept.ExperienceId);
        Assert.Null(kept.AccommodationId);
        Assert.Null(kept.CoverPhotoId);
        Assert.True(kept.Price > 0);
    }

    [Fact]
    public async Task KeepingOneTwiceKeepsItOnce()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        var first = await workspace.KeepAccommodationAsync(guest, listing);
        var second = await workspace.KeepAccommodationAsync(guest, listing);

        Assert.Equal(first.Id, second.Id);
        Assert.Equal(first.CreatedAt, second.CreatedAt);
        Assert.Equal(1, (await workspace.ListAsync(guest)).TotalCount);
    }

    [Fact]
    public async Task TwoTapsAtOnceStillKeepItOnce()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        var race = new RaceInterceptor(
            "INSERT",
            () => workspace.KeepAccommodationAsync(guest, listing));

        var kept = await workspace.KeepAccommodationAsync(guest, listing, race);

        Assert.True(race.Fired);
        Assert.Equal(listing, kept.AccommodationId);
        Assert.Equal(1, (await workspace.ListAsync(guest)).TotalCount);
    }

    [Fact]
    public async Task DroppingOneTakesItOffTheList()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);
        await workspace.DropAccommodationAsync(guest, listing);

        Assert.Equal(0, (await workspace.ListAsync(guest)).TotalCount);
    }

    [Fact]
    public async Task DroppingOneThatWasNeverKeptChangesNothing()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.DropAccommodationAsync(guest, listing);
        await workspace.KeepAccommodationAsync(guest, listing);
        await workspace.DropAccommodationAsync(guest, listing);
        await workspace.DropAccommodationAsync(guest, listing);

        Assert.Equal(0, (await workspace.ListAsync(guest)).TotalCount);
    }

    [Fact]
    public async Task DroppingOneLeavesWhatSomebodyElseKept()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);
        await workspace.KeepAccommodationAsync(somebodyElse, listing);
        await workspace.DropAccommodationAsync(guest, listing);

        Assert.Equal(0, (await workspace.ListAsync(guest)).TotalCount);
        Assert.Equal(1, (await workspace.ListAsync(somebodyElse)).TotalCount);
    }

    [Fact]
    public async Task AListingNobodyMayBrowseCannotBeKept()
    {
        var (host, accommodation) = await workspace.AnAccommodationAsync();
        var (experienceHost, experience) = await workspace.AnExperienceAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.WithdrawAccommodationAsync(host, accommodation);
        await workspace.WithdrawExperienceAsync(experienceHost, experience);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.KeepAccommodationAsync(guest, accommodation));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.KeepExperienceAsync(guest, experience));
    }

    [Fact]
    public async Task AListingDeletedUnderTheWriteAnswersNotFound()
    {
        var (host, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        var race = new RaceInterceptor(
            "INSERT",
            () => workspace.DeleteAccommodationAsync(host, listing));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.KeepAccommodationAsync(guest, listing, race));

        Assert.True(race.Fired);
        Assert.Equal(0, (await workspace.ListAsync(guest)).TotalCount);
    }

    [Fact]
    public async Task AWithdrawnListingStaysOnTheListAndSaysSo()
    {
        var (host, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);
        await workspace.WithdrawAccommodationAsync(host, listing);

        var kept = Assert.Single((await workspace.ListAsync(guest)).Items);

        Assert.Equal(listing, kept.AccommodationId);
        Assert.False(kept.IsListingActive);
    }

    [Fact]
    public async Task AWithdrawnListingCanStillBeDropped()
    {
        var (host, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);
        await workspace.WithdrawAccommodationAsync(host, listing);
        await workspace.DropAccommodationAsync(guest, listing);

        Assert.Equal(0, (await workspace.ListAsync(guest)).TotalCount);
    }

    [Fact]
    public async Task TheListIsOnePersonsAndNobodyElsesToRead()
    {
        var (_, listing) = await workspace.AnAccommodationAsync();
        var guest = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, listing);

        Assert.Equal(1, (await workspace.ListAsync(guest)).TotalCount);
        Assert.Equal(0, (await workspace.ListAsync(somebodyElse)).TotalCount);
    }

    [Fact]
    public async Task TheListNarrowsByWhichCatalogueWasKept()
    {
        var (_, accommodation) = await workspace.AnAccommodationAsync();
        var (_, experience) = await workspace.AnExperienceAsync();
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAccommodationAsync(guest, accommodation);
        await workspace.KeepExperienceAsync(guest, experience);

        Assert.Equal(2, (await workspace.ListAsync(guest)).TotalCount);

        var stays = await workspace.ListAsync(
            guest, new FavoriteSearchRequest { Target = SearchTarget.Accommodations });

        Assert.Equal(accommodation, Assert.Single(stays.Items).AccommodationId);

        var terms = await workspace.ListAsync(
            guest, new FavoriteSearchRequest { Target = SearchTarget.Experiences });

        Assert.Equal(experience, Assert.Single(terms.Items).ExperienceId);
    }

    [Fact]
    public async Task TheSameListingIsKeptByOnePersonInEachCatalogue()
    {
        var (_, accommodation) = await workspace.AnAccommodationAsync();
        var (_, experience) = await workspace.AnExperienceAsync();
        var guest = await workspace.AGuestAsync();

        var stay = await workspace.KeepAccommodationAsync(guest, accommodation);
        var term = await workspace.KeepExperienceAsync(guest, experience);

        Assert.NotEqual(stay.Id, term.Id);
        Assert.Equal(2, (await workspace.ListAsync(guest)).TotalCount);
    }
}
