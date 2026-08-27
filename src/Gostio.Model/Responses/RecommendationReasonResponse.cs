using Gostio.Model.Enums;

namespace Gostio.Model.Responses;

// Detail is the value the reason names, and is absent for a kind that names
// none, such as a price near the one being looked at.
public sealed class RecommendationReasonResponse
{
    public required RecommendationReasonKind Kind { get; init; }

    public required string? Detail { get; init; }
}
