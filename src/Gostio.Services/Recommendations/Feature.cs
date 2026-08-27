using System.Globalization;
using Gostio.Model.Enums;

namespace Gostio.Services.Recommendations;

// The key tells two values of a kind apart, and is empty for a kind that has a
// single axis, such as the price.
public readonly record struct Feature(RecommendationReasonKind Kind, string Key)
{
    public static Feature Of(RecommendationReasonKind kind) => new(kind, string.Empty);

    public static Feature Of(RecommendationReasonKind kind, int id) =>
        new(kind, id.ToString(CultureInfo.InvariantCulture));

    public static Feature Term(string term) =>
        new(RecommendationReasonKind.Term, term.ToLowerInvariant());
}

public sealed record ListingAxis(Feature Feature, string? Detail);

// The weight is one for an axis a listing either has or has not, and the degree
// of fit for one it meets by degrees.
public sealed record WeightedAxis(Feature Feature, double Weight, string? Detail);
