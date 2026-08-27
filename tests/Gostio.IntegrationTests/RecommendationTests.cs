using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class RecommendationTests(DatabaseFixture fixture)
{
    private readonly RecommendationWorkspace workspace = new(fixture);

    [Fact]
    public async Task AGuestIsShownTheCityTheyHaveBeenSearchingAndToldWhy()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();
        var wanted = await workspace.AnAccommodationAsync(host, city);
        var guest = await workspace.AGuestAsync();

        await workspace.SearchAccommodationsAsync(
            guest, new AccommodationSearchRequest { CityId = city });

        var suggestions = await workspace.SuggestAsync(guest, SearchTarget.Accommodations);
        var first = suggestions.Items[0];

        Assert.Equal(wanted, first.ListingId);
        Assert.Equal(SearchTarget.Accommodations, first.Target);
        Assert.Contains(first.Reasons, reason => reason.Kind == RecommendationReasonKind.City);
    }

    [Fact]
    public async Task AListingTheGuestAlreadyKeepsIsNotSuggestedAgain()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();
        var kept = await workspace.AnAccommodationAsync(host, city);
        var other = await workspace.AnAccommodationAsync(host, city);
        var guest = await workspace.AGuestAsync();

        await workspace.KeepAsync(guest, kept);

        var suggested = await workspace.AllSuggestedAsync(guest, SearchTarget.Accommodations);

        Assert.Contains(other, suggested);
        Assert.DoesNotContain(kept, suggested);
    }

    [Fact]
    public async Task AHostIsNeverSuggestedTheirOwnListing()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();
        var mine = await workspace.AnAccommodationAsync(host, city);
        var somebodyElse = await workspace.AHostAsync();
        var theirs = await workspace.AnAccommodationAsync(somebodyElse, city);

        await workspace.SearchAccommodationsAsync(
            host, new AccommodationSearchRequest { CityId = city });

        var suggested = await workspace.AllSuggestedAsync(
            host, SearchTarget.Accommodations, RoleNames.Host);

        Assert.Equal(theirs, suggested[0]);
        Assert.DoesNotContain(mine, suggested);
    }

    [Fact]
    public async Task AWithdrawnListingIsNotSuggested()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();
        var offered = await workspace.AnAccommodationAsync(host, city);
        var withdrawn = await workspace.AnAccommodationAsync(host, city);
        var guest = await workspace.AGuestAsync();

        await workspace.WithdrawAsync(host, withdrawn, city);

        await workspace.SearchAccommodationsAsync(
            guest, new AccommodationSearchRequest { CityId = city });

        var suggested = await workspace.AllSuggestedAsync(guest, SearchTarget.Accommodations);

        Assert.Equal(offered, suggested[0]);
        Assert.DoesNotContain(withdrawn, suggested);
    }

    [Fact]
    public async Task AnExperienceWithNoTermStillAheadOfItIsNotSuggested()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();
        var running = await workspace.AnExperienceAsync(host, city, withTerm: true);
        var over = await workspace.AnExperienceAsync(host, city, withTerm: false);
        var guest = await workspace.AGuestAsync();

        await workspace.SearchExperiencesAsync(
            guest, new ExperienceSearchRequest { CityId = city });

        var suggested = await workspace.AllSuggestedAsync(guest, SearchTarget.Experiences);

        Assert.Equal(running, suggested[0]);
        Assert.DoesNotContain(over, suggested);
    }

    [Fact]
    public async Task AnExperienceSeatingThePartyOutranksOneThatCannotHoldIt()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();
        var roomy = await workspace.AnExperienceAsync(host, city, withTerm: true, capacity: 8);
        var cramped = await workspace.AnExperienceAsync(host, city, withTerm: true, capacity: 1);
        var guest = await workspace.AGuestAsync();

        await workspace.SearchExperiencesAsync(
            guest, new ExperienceSearchRequest { CityId = city, Places = 6 });

        var suggestions = await workspace.SuggestAsync(guest, SearchTarget.Experiences);
        var first = suggestions.Items[0];

        Assert.Equal(roomy, first.ListingId);
        Assert.Contains(first.Reasons, reason => reason.Kind == RecommendationReasonKind.Capacity);
        Assert.Contains(cramped, suggestions.Items.Select(one => one.ListingId));
    }

    [Fact]
    public async Task AGuestWhoHasDoneNothingIsStillGivenTheCatalogueInOrder()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();

        await workspace.AnAccommodationAsync(host, city);

        var guest = await workspace.AGuestAsync();

        var suggestions = await workspace.SuggestAsync(guest, SearchTarget.Accommodations);
        var scores = suggestions.Items.Select(suggestion => suggestion.Score).ToList();

        Assert.NotEmpty(suggestions.Items);
        Assert.Equal(scores.OrderByDescending(score => score), scores);
        Assert.All(scores, score => Assert.InRange(score, 0, 1));
        Assert.All(suggestions.Items, suggestion => Assert.NotEmpty(suggestion.Reasons));
    }

    [Fact]
    public async Task ThePageIsCutFromTheWholeRanking()
    {
        var city = await workspace.ACityOfItsOwnAsync();
        var host = await workspace.AHostAsync();

        await workspace.AnAccommodationAsync(host, city);
        await workspace.AnAccommodationAsync(host, city);

        var guest = await workspace.AGuestAsync();

        var page = await workspace.SuggestAsync(guest, SearchTarget.Accommodations, pageSize: 1);

        Assert.Single(page.Items);
        Assert.True(page.TotalCount > 1);
    }

    [Fact]
    public async Task ACatalogueHasToBeNamed()
    {
        var guest = await workspace.AGuestAsync();

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.SuggestAsync(guest, target: null));
    }

    [Fact]
    public async Task NothingIsSuggestedToNobody() =>
        await Assert.ThrowsAsync<UnauthorizedException>(workspace.SuggestToNobodyAsync);
}
