using Gostio.Model.Enums;
using Gostio.Services.Recommendations;

namespace Gostio.Tests.Recommendations;

public class RecommendationScoringTests
{
    private static readonly DateTime Now = new(2026, 8, 27, 12, 0, 0, DateTimeKind.Utc);

    private static readonly TasteProfile Nothing = TasteProfile.Build([], [], Now);

    private static readonly Candidate Listing = new()
    {
        ListingId = 1,
        Target = SearchTarget.Accommodations,
        Title = "A place to stay",
        CityName = "Sarajevo",
        CountryName = "Bosnia and Herzegovina",
        CategoryName = "City break",
        Price = 100m,
        MaxGuests = 4,
        CoverPhotoId = null,
        AverageRating = null,
        ReviewCount = 0,
        Engagements = 0,
        Axes = [],
    };

    [Fact]
    public void AGuestWhoHasLeftNoSignalsIsShownWhatOtherGuestsRatedHighest()
    {
        var loved = Listing with { ListingId = 1, AverageRating = 4.8m, ReviewCount = 20 };
        var ignored = Listing with { ListingId = 2, AverageRating = 2.4m, ReviewCount = 20 };

        var ranked = RecommendationScoring.Rank(Nothing, [ignored, loved]);

        Assert.Equal(1, ranked[0].Listing.ListingId);
        Assert.Equal(RecommendationReasonKind.Rating, Assert.Single(ranked[0].Reasons).Kind);
    }

    [Fact]
    public void AListingGuestsKeepAndBookOutranksOneNobodyHasTouched()
    {
        var busy = Listing with { ListingId = 1, Engagements = 20 };
        var quiet = Listing with { ListingId = 2, Engagements = 0 };

        var ranked = RecommendationScoring.Rank(Nothing, [quiet, busy]);

        Assert.Equal(1, ranked[0].Listing.ListingId);
        Assert.Equal(RecommendationReasonKind.Popularity, Assert.Single(ranked[0].Reasons).Kind);
        Assert.Equal("20", Assert.Single(ranked[0].Reasons).Detail);
    }

    [Fact]
    public void AListingWithASingleReviewDoesNotOutrankOneManyGuestsRated()
    {
        var alone = Listing with { ListingId = 1, AverageRating = 5m, ReviewCount = 1 };
        var many = Listing with { ListingId = 2, AverageRating = 4.5m, ReviewCount = 40 };
        var crowd = Listing with { ListingId = 3, AverageRating = 3m, ReviewCount = 100 };

        var ranked = RecommendationScoring.Rank(Nothing, [alone, many, crowd]);

        Assert.Equal(2, ranked[0].Listing.ListingId);
    }

    [Fact]
    public void AListingInTheCityBeingSearchedComesFirstAndSaysSo()
    {
        var profile = TasteProfile.Build([Searched(cityId: 7)], [], Now);
        var here = Listing with { ListingId = 1, Axes = [City(7)] };
        var elsewhere = Listing with { ListingId = 2, Axes = [City(9)] };

        var ranked = RecommendationScoring.Rank(profile, [elsewhere, here]);

        Assert.Equal(1, ranked[0].Listing.ListingId);

        var reason = Assert.Single(ranked[0].Reasons);

        Assert.Equal(RecommendationReasonKind.City, reason.Kind);
        Assert.Equal("Sarajevo", reason.Detail);
    }

    [Fact]
    public void ATitleCarryingATermTheGuestTypedIsWhatTheSuggestionNames()
    {
        var profile = TasteProfile.Build([Searched(term: "old town")], [], Now);
        var matching = Listing with { ListingId = 1, Title = "Loft in the Old Town" };
        var other = Listing with { ListingId = 2, Title = "Loft by the river" };

        var ranked = RecommendationScoring.Rank(profile, [other, matching]);

        Assert.Equal(1, ranked[0].Listing.ListingId);

        var reason = Assert.Single(ranked[0].Reasons);

        Assert.Equal(RecommendationReasonKind.Term, reason.Kind);
        Assert.Equal("old town", reason.Detail);
    }

    [Fact]
    public void APriceNearTheOneBeingAskedForOutranksOneFarFromIt()
    {
        var profile = TasteProfile.Build([Searched(minPrice: 80m, maxPrice: 100m)], [], Now);
        var near = Listing with { ListingId = 1, Price = 95m };
        var far = Listing with { ListingId = 2, Price = 400m };

        var ranked = RecommendationScoring.Rank(profile, [far, near]);

        Assert.Equal(1, ranked[0].Listing.ListingId);
        Assert.Equal(RecommendationReasonKind.Price, Assert.Single(ranked[0].Reasons).Kind);
        Assert.Null(Assert.Single(ranked[0].Reasons).Detail);
    }

    [Fact]
    public void APlaceTooSmallForThePartyFallsBehindOneThatFits()
    {
        var profile = TasteProfile.Build([Searched(guestCount: 4)], [], Now);
        var fits = Listing with { ListingId = 1, MaxGuests = 4 };
        var cramped = Listing with { ListingId = 2, MaxGuests = 1 };

        var ranked = RecommendationScoring.Rank(profile, [cramped, fits]);

        Assert.Equal(1, ranked[0].Listing.ListingId);
        Assert.Equal(RecommendationReasonKind.Capacity, Assert.Single(ranked[0].Reasons).Kind);
    }

    [Fact]
    public void AGuestWhoseSignalsMatchNothingStillGetsTheCatalogueInOrder()
    {
        var profile = TasteProfile.Build([Searched(cityId: 7)], [], Now);
        var loved = Listing with
        {
            ListingId = 1,
            Axes = [City(9)],
            AverageRating = 4.8m,
            ReviewCount = 20,
        };
        var ignored = Listing with
        {
            ListingId = 2,
            Axes = [City(9)],
            AverageRating = 2.4m,
            ReviewCount = 20,
        };

        var ranked = RecommendationScoring.Rank(profile, [ignored, loved]);

        Assert.Equal(2, ranked.Count);
        Assert.Equal(1, ranked[0].Listing.ListingId);
    }

    [Fact]
    public void NoSuggestionCarriesMoreReasonsThanAScreenCanShow()
    {
        var profile = TasteProfile.Build(
            [Searched(cityId: 7, term: "loft", minPrice: 90m, maxPrice: 110m, guestCount: 2)],
            [Kept(City(7), Category(3), Type(2))],
            Now);

        var everything = Listing with
        {
            Title = "A loft in the old town",
            Axes = [City(7), Category(3), Type(2)],
        };

        var ranked = RecommendationScoring.Rank(profile, [everything]);

        Assert.Equal(RecommendationWeights.MaximumReasons, ranked[0].Reasons.Count);
    }

    [Fact]
    public void EveryScoreStaysInsideTheScale()
    {
        var profile = TasteProfile.Build(
            [Searched(cityId: 7, guestCount: 2)], [Kept(City(7))], Now);

        var matching = Listing with
        {
            ListingId = 1,
            Axes = [City(7)],
            AverageRating = 5m,
            ReviewCount = 9,
        };

        var plain = Listing with { ListingId = 2, Axes = [City(9)], Engagements = 4 };

        var ranked = RecommendationScoring.Rank(profile, [matching, plain]);

        Assert.All(ranked, scored => Assert.InRange(scored.Score, 0, 1));
    }

    [Fact]
    public void ASuggestionNothingSpokeForSaysThatMuch()
    {
        var ranked = RecommendationScoring.Rank(Nothing, [Listing]);

        var reason = Assert.Single(ranked[0].Reasons);

        Assert.Equal(RecommendationReasonKind.OnOffer, reason.Kind);
        Assert.Null(reason.Detail);
    }

    [Fact]
    public void AGuestWhoseSignalsReachNothingIsRankedAsOneWhoLeftNone()
    {
        var profile = TasteProfile.Build([Searched(cityId: 7)], [], Now);
        var elsewhere = Listing with { Axes = [City(9)] };

        var reached = RecommendationScoring.Rank(profile, [elsewhere]);
        var cold = RecommendationScoring.Rank(Nothing, [elsewhere]);

        Assert.Equal(cold[0].Score, reached[0].Score);
    }

    [Fact]
    public void TwoListingsThatMatchAlikeAreOrderedByTheirId()
    {
        var first = Listing with { ListingId = 4 };
        var second = Listing with { ListingId = 9 };

        var ranked = RecommendationScoring.Rank(Nothing, [second, first]);

        Assert.Equal([4, 9], ranked.Select(scored => scored.Listing.ListingId));
    }

    private static ListingAxis City(int id) =>
        new(Feature.Of(RecommendationReasonKind.City, id), "Sarajevo");

    private static ListingAxis Category(int id) =>
        new(Feature.Of(RecommendationReasonKind.Category, id), "City break");

    private static ListingAxis Type(int id) =>
        new(Feature.Of(RecommendationReasonKind.AccommodationType, id), "Apartment");

    private static EngagedListing Kept(params ListingAxis[] axes) =>
        new(1, EngagementKind.Favorite, null, Now, 100m, axes);

    private static SearchedSignal Searched(
        string? term = null,
        int? cityId = null,
        int? guestCount = null,
        decimal? minPrice = null,
        decimal? maxPrice = null) =>
        new(term, cityId, guestCount, minPrice, maxPrice, Now);
}
