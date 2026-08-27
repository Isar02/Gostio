using System.Globalization;
using Gostio.Model.Enums;
using Gostio.Model.Responses;
using Gostio.Model.Validation;

namespace Gostio.Services.Recommendations;

public sealed record Candidate
{
    public required int ListingId { get; init; }

    public required SearchTarget Target { get; init; }

    public required string Title { get; init; }

    public required string CityName { get; init; }

    public required string CountryName { get; init; }

    public required string CategoryName { get; init; }

    public required decimal Price { get; init; }

    public required int? MaxGuests { get; init; }

    public required int? CoverPhotoId { get; init; }

    public required decimal? AverageRating { get; init; }

    public required int ReviewCount { get; init; }

    public required int Engagements { get; init; }

    // Filled after the query: an axis is built out of calls no database runs.
    public IReadOnlyList<ListingAxis> Axes { get; init; } = [];
}

public sealed record ScoredCandidate(
    Candidate Listing,
    double Score,
    IReadOnlyList<RecommendationReasonResponse> Reasons);

public static class RecommendationScoring
{
    private const int ScoreDecimals = 4;

    private const string RatingFormat = "0.0";

    public static IReadOnlyList<ScoredCandidate> Rank(
        TasteProfile profile,
        IReadOnlyList<Candidate> candidates)
    {
        List<Measured> measured = [.. candidates.Select(candidate => Measure(profile, candidate))];

        var ranking = new Ranking(
            Prior(candidates),
            candidates.Count == 0 ? 0 : candidates.Max(one => one.Engagements),
            measured.Count == 0 ? 0 : measured.Max(one => one.Matched));

        return [.. measured
            .Select(one => Score(profile, one, ranking))
            .OrderByDescending(scored => scored.Score)
            .ThenBy(scored => scored.Listing.ListingId)];
    }

    private static ScoredCandidate Score(TasteProfile profile, Measured measured, Ranking ranking)
    {
        var quality = Quality(measured.Listing, ranking.Prior);
        var popularity = Popularity(measured.Listing, ranking.MostEngaged);

        var score = ranking.NothingMatched
            ? (RecommendationWeights.ColdQuality * quality)
                + (RecommendationWeights.ColdPopularity * popularity)
            : (RecommendationWeights.Content * Share(measured.Matched, ranking.Strongest))
                + (RecommendationWeights.Quality * quality)
                + (RecommendationWeights.Popularity * popularity);

        return new ScoredCandidate(
            measured.Listing,
            Math.Round(score, ScoreDecimals),
            Reasons(profile, measured.Vector, measured.Listing, ranking.Prior));
    }

    private static Measured Measure(TasteProfile profile, Candidate candidate)
    {
        var vector = Vector(profile, candidate);

        return new Measured(candidate, vector, vector.Sum(axis => Contribution(profile, axis)));
    }

    private static IReadOnlyList<WeightedAxis> Vector(TasteProfile profile, Candidate candidate)
    {
        List<WeightedAxis> vector =
            [.. candidate.Axes.Select(axis => new WeightedAxis(axis.Feature, 1, axis.Detail))];

        foreach (var term in Terms(profile, candidate.Title))
        {
            vector.Add(new WeightedAxis(Feature.Term(term), 1, term));
        }

        if (PriceFit(profile, candidate) is double price)
        {
            vector.Add(new WeightedAxis(Feature.Of(RecommendationReasonKind.Price), price, null));
        }

        if (CapacityFit(profile, candidate) is double capacity)
        {
            vector.Add(
                new WeightedAxis(Feature.Of(RecommendationReasonKind.Capacity), capacity, null));
        }

        return vector;
    }

    private static IReadOnlyList<string> Terms(TasteProfile profile, string title)
    {
        var lowered = title.ToLowerInvariant();

        return [.. profile.Weights.Keys
            .Where(feature => feature.Kind == RecommendationReasonKind.Term)
            .Select(feature => feature.Key)
            .Where(lowered.Contains)
            .Order(StringComparer.Ordinal)];
    }

    private static double? PriceFit(TasteProfile profile, Candidate candidate)
    {
        if (profile.PreferredPrice is not decimal preferred || preferred <= 0)
        {
            return null;
        }

        var asked = (double)preferred;

        return asked / (asked + Math.Abs((double)candidate.Price - asked));
    }

    private static double? CapacityFit(TasteProfile profile, Candidate candidate)
    {
        if (profile.PreferredGuests is not int party || candidate.MaxGuests is not int room)
        {
            return null;
        }

        return room >= party ? 1 : (double)room / party;
    }

    private static double Contribution(TasteProfile profile, WeightedAxis axis) =>
        profile.Weights.GetValueOrDefault(axis.Feature) * axis.Weight;

    private static double Share(double matched, double strongest) =>
        strongest <= 0 ? 0 : matched / strongest;

    private static double Quality(Candidate candidate, double prior)
    {
        var average = (double?)candidate.AverageRating ?? 0;

        var weighted =
            ((candidate.ReviewCount * average) + (RecommendationWeights.RatingPrior * prior))
            / (candidate.ReviewCount + RecommendationWeights.RatingPrior);

        return (weighted - ReviewRatings.Lowest) / (ReviewRatings.Highest - ReviewRatings.Lowest);
    }

    private static double Prior(IReadOnlyList<Candidate> candidates)
    {
        var reviews = candidates.Sum(candidate => candidate.ReviewCount);

        return reviews == 0
            ? (ReviewRatings.Lowest + ReviewRatings.Highest) / 2.0
            : candidates.Sum(one => one.ReviewCount * (double)(one.AverageRating ?? 0)) / reviews;
    }

    private static double Popularity(Candidate candidate, int mostEngaged) =>
        mostEngaged <= 0 ? 0 : Math.Log(1 + candidate.Engagements) / Math.Log(1 + mostEngaged);

    private static IReadOnlyList<RecommendationReasonResponse> Reasons(
        TasteProfile profile,
        IReadOnlyList<WeightedAxis> vector,
        Candidate candidate,
        double prior)
    {
        List<RecommendationReasonResponse> reasons = [.. vector
            .Select(axis => (Axis: axis, Weight: Contribution(profile, axis)))
            .Where(scored => scored.Weight > 0)
            .OrderByDescending(scored => scored.Weight)
            .ThenBy(scored => scored.Axis.Feature.Kind)
            .ThenBy(scored => scored.Axis.Feature.Key, StringComparer.Ordinal)
            .Take(RecommendationWeights.MaximumReasons)
            .Select(scored => Reason(scored.Axis.Feature.Kind, scored.Axis.Detail))];

        if (Room(reasons) && candidate.AverageRating is decimal rating && (double)rating >= prior)
        {
            reasons.Add(Reason(
                RecommendationReasonKind.Rating,
                rating.ToString(RatingFormat, CultureInfo.InvariantCulture)));
        }

        if (Room(reasons) && candidate.Engagements > 0)
        {
            reasons.Add(Reason(
                RecommendationReasonKind.Popularity,
                candidate.Engagements.ToString(CultureInfo.InvariantCulture)));
        }

        if (reasons.Count == 0)
        {
            reasons.Add(Reason(RecommendationReasonKind.OnOffer, null));
        }

        return reasons;
    }

    private static bool Room(List<RecommendationReasonResponse> reasons) =>
        reasons.Count < RecommendationWeights.MaximumReasons;

    private static RecommendationReasonResponse Reason(
        RecommendationReasonKind kind,
        string? detail) =>
        new() { Kind = kind, Detail = detail };

    private sealed record Measured(
        Candidate Listing,
        IReadOnlyList<WeightedAxis> Vector,
        double Matched);

    private sealed record Ranking(double Prior, int MostEngaged, double Strongest)
    {
        public bool NothingMatched => Strongest <= 0;
    }
}
