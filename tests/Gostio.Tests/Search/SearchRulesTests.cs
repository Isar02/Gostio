using Gostio.Model.Enums;
using Gostio.Model.Validation;
using Gostio.Services.Search;

namespace Gostio.Tests.Search;

public class SearchRulesTests
{
    private static readonly SearchSignal Nothing =
        new() { Target = SearchTarget.Accommodations };

    private static readonly SearchSignal Typed = new()
    {
        Target = SearchTarget.Accommodations,
        Term = "old town",
        CityId = 3,
        GuestCount = 2,
        MinPrice = 40m,
        MaxPrice = 120m,
    };

    [Fact]
    public void ASearchThatNamesNothingIsNotWorthRecording() =>
        Assert.False(SearchRules.NamesSomething(Nothing));

    [Fact]
    public void ATermOfNothingButSpacesNamesNothing() =>
        Assert.False(SearchRules.NamesSomething(Nothing with { Term = "   " }));

    public static TheoryData<SearchSignal> OneThingNamed => new(
        Nothing with { Term = "loft" },
        Nothing with { CityId = 3 },
        Nothing with { GuestCount = 2 },
        Nothing with { MinPrice = 40m },
        Nothing with { MaxPrice = 120m });

    [Theory]
    [MemberData(nameof(OneThingNamed))]
    public void AnythingASearchNamesIsEnoughToRecordIt(SearchSignal signal) =>
        Assert.True(SearchRules.NamesSomething(signal));

    [Fact]
    public void ATermStillBeingTypedContinuesTheSearchBeforeIt() =>
        Assert.True(SearchRules.Continues(Typed, Typed with { Term = "old" }));

    [Fact]
    public void ATermBeingErasedContinuesItTheSameWay() =>
        Assert.True(SearchRules.Continues(Typed with { Term = "old" }, Typed));

    [Fact]
    public void TheSameSearchRunTwiceContinuesItself() =>
        Assert.True(SearchRules.Continues(Typed, Typed));

    [Fact]
    public void CaseIsNotWhatTellsTwoSearchesApart() =>
        Assert.True(SearchRules.Continues(Typed with { Term = "OLD TOWN" }, Typed));

    [Fact]
    public void TheFirstCharacterTypedIntoAnEmptyBoxContinuesTheSearch() =>
        Assert.True(SearchRules.Continues(Typed, Typed with { Term = null }));

    [Fact]
    public void AnUnrelatedTermIsASearchOfItsOwn() =>
        Assert.False(SearchRules.Continues(Typed, Typed with { Term = "villa" }));

    public static TheoryData<SearchSignal> OneThingChanged => new(
        Typed with { Target = SearchTarget.Experiences },
        Typed with { CityId = 4 },
        Typed with { CityId = null },
        Typed with { GuestCount = 3 },
        Typed with { MinPrice = 50m },
        Typed with { MaxPrice = null });

    [Theory]
    [MemberData(nameof(OneThingChanged))]
    public void AFilterMovingMakesASearchOfItsOwn(SearchSignal signal) =>
        Assert.False(SearchRules.Continues(signal, Typed));

    // The column has to hold whatever a search accepts, or a recorded term
    // would be the guest's words cut short and the recommender would match on
    // the cut.
    [Fact]
    public void TheColumnHoldsEveryTermASearchAccepts() =>
        Assert.True(ColumnLengths.Title <= ColumnLengths.SearchTerm);
}
