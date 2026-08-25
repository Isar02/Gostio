using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

public sealed class HostVerificationSearchRequest : PagedRequest
{
    public HostVerificationStatus? Status { get; set; }

    public int? UserId { get; set; }
}
