using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

public sealed class RecommendationSearchRequest : PagedRequest
{
    public SearchTarget? Target { get; set; }
}
