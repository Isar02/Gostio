using Gostio.Model.Enums;
using Gostio.Model.Validation;
using Gostio.Services.Recommendations;

namespace Gostio.Tests.Recommendations;

public class TasteProfileTests
{
    private const int Precision = 6;

    private const decimal Paid = 100m;

    private static readonly DateTime Now = new(2026, 8, 27, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void AGuestWhoHasDoneNothingHasNoTaste()
    {
        var profile = TasteProfile.Build([], [], Now);

        Assert.Empty(profile.Weights);
        Assert.Null(profile.PreferredPrice);
        Assert.Null(profile.PreferredGuests);
    }

    [Fact]
    public void AKeptListingPutsItsOwnAxesIntoTheProfile()
    {
        var profile = TasteProfile.Build([], [Kept(City(7), Category(3))], Now);

        Assert.Equal(RecommendationWeights.Favorite, Weight(profile, City(7)), Precision);
        Assert.Equal(RecommendationWeights.Favorite, Weight(profile, Category(3)), Precision);
        Assert.Equal(Paid, profile.PreferredPrice);
    }

    [Fact]
    public void ABookingWeighsMoreThanSomethingMerelyKept()
    {
        var kept = TasteProfile.Build([], [Kept(City(7))], Now);
        var booked = TasteProfile.Build([], [Booked(null, City(7))], Now);

        Assert.True(Weight(booked, City(7)) > Weight(kept, City(7)));
    }

    [Fact]
    public void AStayRatedAtTheBottomOfTheScaleSaysNothingAboutTheGuest()
    {
        var profile = TasteProfile.Build([], [Booked(ReviewRatings.Lowest, City(7))], Now);

        Assert.Empty(profile.Weights);
    }

    [Fact]
    public void AnAmenityDoesNotOutweighTheCityByBeingOneOfMany()
    {
        var kept = Kept(City(7), Amenity(1), Amenity(2), Amenity(3), Amenity(4));

        var profile = TasteProfile.Build([], [kept], Now);

        Assert.Equal(RecommendationWeights.Favorite, Weight(profile, City(7)), Precision);
        Assert.Equal(RecommendationWeights.Favorite / 4, Weight(profile, Amenity(1)), Precision);
    }

    [Fact]
    public void ASignalOneHalfLifeOldWeighsHalfOfAFreshOne()
    {
        var older = Kept(City(7)) with { At = Now - RecommendationWeights.HalfLife };

        var profile = TasteProfile.Build([], [older], Now);

        Assert.Equal(RecommendationWeights.Favorite / 2, Weight(profile, City(7)), Precision);
    }

    [Fact]
    public void ATermTooShortToNarrowAnythingIsNotATerm()
    {
        var profile = TasteProfile.Build([Searched(term: "ol")], [], Now);

        Assert.Empty(profile.Weights);
    }

    [Fact]
    public void OneTermTypedTwoWaysIsOneAxis()
    {
        var searches = new[] { Searched(term: "Old Town"), Searched(term: "old town") };

        var profile = TasteProfile.Build(searches, [], Now);

        Assert.Equal(
            2 * RecommendationWeights.Search,
            Weight(profile, Feature.Term("old town")),
            Precision);
    }

    [Fact]
    public void APriceRangeNamesItsMiddleAndOneBoundNamesItself()
    {
        var range = TasteProfile.Build([Searched(minPrice: 40m, maxPrice: 120m)], [], Now);
        var ceiling = TasteProfile.Build([Searched(maxPrice: 80m)], [], Now);

        Assert.Equal(80m, range.PreferredPrice);
        Assert.Equal(80m, ceiling.PreferredPrice);
    }

    [Fact]
    public void ThePartyIsTheMeanOfTheOnesSearchedFor()
    {
        var searches = new[] { Searched(guestCount: 2), Searched(guestCount: 4) };

        var profile = TasteProfile.Build(searches, [], Now);

        Assert.Equal(3, profile.PreferredGuests);
    }

    private static ListingAxis City(int id) =>
        new(Feature.Of(RecommendationReasonKind.City, id), "Sarajevo");

    private static ListingAxis Category(int id) =>
        new(Feature.Of(RecommendationReasonKind.Category, id), "City break");

    private static ListingAxis Amenity(int id) =>
        new(Feature.Of(RecommendationReasonKind.Amenity, id), $"Amenity {id}");

    private static EngagedListing Kept(params ListingAxis[] axes) =>
        new(1, EngagementKind.Favorite, null, Now, Paid, axes);

    private static EngagedListing Booked(int? rating, params ListingAxis[] axes) =>
        new(1, EngagementKind.Booking, rating, Now, Paid, axes);

    private static SearchedSignal Searched(
        string? term = null,
        int? cityId = null,
        int? guestCount = null,
        decimal? minPrice = null,
        decimal? maxPrice = null) =>
        new(term, cityId, guestCount, minPrice, maxPrice, Now);

    private static double Weight(TasteProfile profile, ListingAxis axis) =>
        Weight(profile, axis.Feature);

    private static double Weight(TasteProfile profile, Feature feature) =>
        profile.Weights.GetValueOrDefault(feature);
}
