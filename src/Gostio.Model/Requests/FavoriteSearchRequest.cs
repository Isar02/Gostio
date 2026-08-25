using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

public sealed class FavoriteSearchRequest : PagedRequest
{
    public SearchTarget? Target { get; set; }
}
