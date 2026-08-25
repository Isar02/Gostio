using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ListingRatingTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-somebody-reading-a-card";

    private readonly ReviewWorkspace workspace = new(fixture);

    private readonly AccommodationWorkspace listings = new(fixture);

    [Fact]
    public async Task AnAccommodationCarriesTheAverageOfWhatItsGuestsSaid()
    {
        var first = await workspace.ACompletedStayAsync();
        var second = await workspace.ACompletedStayAsync(sameListingAs: first);

        await workspace.WriteAsync(first.Guest, RoleNames.Guest, first.Booking, rating: 5);
        await workspace.WriteAsync(second.Guest, RoleNames.Guest, second.Booking, rating: 4);

        var card = await ReadAccommodationAsync(first.Host, first.Accommodation);

        Assert.Equal(4.5m, card.AverageRating);
        Assert.Equal(2, card.ReviewCount);
    }

    // SQL Server divides to average, and division takes the scale up, so what
    // comes back is the exact quotient rather than a rounded one.
    [Fact]
    public async Task ARatingThatDoesNotDivideEvenlyComesBackUnrounded()
    {
        var first = await workspace.ACompletedStayAsync();
        var second = await workspace.ACompletedStayAsync(sameListingAs: first);
        var third = await workspace.ACompletedStayAsync(sameListingAs: first);

        await workspace.WriteAsync(first.Guest, RoleNames.Guest, first.Booking, rating: 4);
        await workspace.WriteAsync(second.Guest, RoleNames.Guest, second.Booking, rating: 4);
        await workspace.WriteAsync(third.Guest, RoleNames.Guest, third.Booking, rating: 5);

        var card = await ReadAccommodationAsync(first.Host, first.Accommodation);

        Assert.Equal(4.333333m, card.AverageRating);
        Assert.Equal(3, card.ReviewCount);
    }

    [Fact]
    public async Task AnExperienceCarriesWhatItsGuestsSaid()
    {
        var term = await workspace.ACompletedTermAsync();

        await workspace.WriteAsync(term.Guest, RoleNames.Guest, term.Booking, rating: 3);

        var card = await ReadExperienceAsync(term.Host, term.Experience);

        Assert.Equal(3m, card.AverageRating);
        Assert.Equal(1, card.ReviewCount);
    }

    [Fact]
    public async Task AListingNobodyHasReviewedCarriesNoRatingAtAll()
    {
        var (host, listing) = await listings.AListingAsync(Password);

        var card = await ReadAccommodationAsync(host, listing);

        Assert.Null(card.AverageRating);
        Assert.Equal(0, card.ReviewCount);
    }

    // The search and the single read stand on one projection, and this is what
    // says so: a rating written into only one of them would pass every test
    // above.
    [Fact]
    public async Task ASearchCarriesTheRatingTheSingleReadDoes()
    {
        var stay = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 2);

        var found = await FoundAccommodationAsync(stay.Host, stay.Accommodation);

        Assert.Equal(2m, found.AverageRating);
        Assert.Equal(1, found.ReviewCount);
    }

    [Fact]
    public async Task AListingCarriesOnlyTheReviewsOfItsOwnBookings()
    {
        var stay = await workspace.ACompletedStayAsync();
        var other = await listings.CreateAsync(stay.Host, $"Another listing {Guid.NewGuid():N}");

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 5);

        var card = await ReadAccommodationAsync(stay.Host, other);

        Assert.Null(card.AverageRating);
        Assert.Equal(0, card.ReviewCount);
    }

    [Fact]
    public async Task AnExperienceCarriesOnlyTheReviewsOfItsOwnTerms()
    {
        var reviewed = await workspace.ACompletedTermAsync();
        var other = await workspace.ACompletedTermAsync();

        await workspace.WriteAsync(reviewed.Guest, RoleNames.Guest, reviewed.Booking, rating: 5);

        var card = await ReadExperienceAsync(other.Host, other.Experience);

        Assert.Null(card.AverageRating);
        Assert.Equal(0, card.ReviewCount);
    }

    private Task<AccommodationResponse> ReadAccommodationAsync(int actor, int listing) =>
        AsHostAsync(
            actor, (IAccommodationService service) => service.GetAsync(listing, default));

    private Task<ExperienceResponse> ReadExperienceAsync(int actor, int experience) =>
        AsHostAsync(
            actor, (IExperienceService service) => service.GetAsync(experience, default));

    private async Task<AccommodationResponse> FoundAccommodationAsync(int actor, int listing)
    {
        var page = await AsHostAsync(
            actor,
            (IAccommodationService service) => service.SearchAsync(
                new AccommodationSearchRequest { HostId = actor }, default));

        return page.Items.Single(item => item.Id == listing);
    }

    private async Task<TResult> AsHostAsync<TService, TResult>(
        int actor,
        Func<TService, Task<TResult>> work)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, RoleNames.Host));

        return await work(services.GetRequiredService<TService>());
    }
}
