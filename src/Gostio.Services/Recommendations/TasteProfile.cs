using Gostio.Model.Enums;

namespace Gostio.Services.Recommendations;

public sealed record TasteProfile
{
    public required IReadOnlyDictionary<Feature, double> Weights { get; init; }

    public required decimal? PreferredPrice { get; init; }

    public required int? PreferredGuests { get; init; }

    public static TasteProfile Build(
        IReadOnlyList<SearchedSignal> searches,
        IReadOnlyList<EngagedListing> engagements,
        DateTime now)
    {
        var weights = new Dictionary<Feature, double>();
        var price = new WeightedMean();
        var guests = new WeightedMean();

        foreach (var engagement in engagements)
        {
            var weight = RecommendationWeights.Of(engagement.Kind, engagement.Rating)
                * RecommendationWeights.Decay(now, engagement.At);

            if (weight <= 0)
            {
                continue;
            }

            Spread(weights, engagement.Axes, weight);

            Add(weights, Feature.Of(RecommendationReasonKind.Price), weight);
            price.Add((double)engagement.Price, weight);
        }

        foreach (var search in searches)
        {
            var weight = RecommendationWeights.Search * RecommendationWeights.Decay(now, search.At);

            if (search.CityId is int cityId)
            {
                Add(weights, Feature.Of(RecommendationReasonKind.City, cityId), weight);
            }

            if (Typed(search.Term) is string term)
            {
                Add(weights, Feature.Term(term), weight);
            }

            if (Asked(search.MinPrice, search.MaxPrice) is double asked)
            {
                Add(weights, Feature.Of(RecommendationReasonKind.Price), weight);
                price.Add(asked, weight);
            }

            if (search.GuestCount is int party and > 0)
            {
                Add(weights, Feature.Of(RecommendationReasonKind.Capacity), weight);
                guests.Add(party, weight);
            }
        }

        return new TasteProfile
        {
            Weights = weights,
            PreferredPrice = price.Mean is double mean ? (decimal)mean : null,
            PreferredGuests = guests.Mean is double wanted
                ? Math.Max(1, (int)Math.Round(wanted, MidpointRounding.AwayFromZero))
                : null,
        };
    }

    // A kind carries the whole of the signal's weight, divided between the
    // values the listing has of it.
    private static void Spread(
        Dictionary<Feature, double> weights,
        IReadOnlyList<ListingAxis> axes,
        double weight)
    {
        foreach (var kind in axes.GroupBy(axis => axis.Feature.Kind))
        {
            var share = weight / kind.Count();

            foreach (var axis in kind)
            {
                Add(weights, axis.Feature, share);
            }
        }
    }

    private static void Add(Dictionary<Feature, double> weights, Feature feature, double weight) =>
        weights[feature] = weights.GetValueOrDefault(feature) + weight;

    private static string? Typed(string? term) =>
        term?.Trim() is { Length: >= RecommendationWeights.ShortestTerm } typed ? typed : null;

    private static double? Asked(decimal? minimum, decimal? maximum) => (minimum, maximum) switch
    {
        (decimal low, decimal high) => (double)(low + high) / 2,
        (decimal low, null) => (double)low,
        (null, decimal high) => (double)high,
        _ => null,
    };

    private sealed class WeightedMean
    {
        private double total;

        private double weight;

        public double? Mean => weight > 0 ? total / weight : null;

        public void Add(double value, double by)
        {
            total += value * by;
            weight += by;
        }
    }
}
