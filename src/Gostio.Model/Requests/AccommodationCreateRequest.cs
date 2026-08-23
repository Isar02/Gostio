using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class AccommodationCreateRequest : AccommodationUpsertRequest
{
    // Absent means the caller keeps the listing; an administrator names a host
    // instead, because they are not the one letting the place out.
    [Range(1, int.MaxValue, ErrorMessage = "Choose the host this accommodation belongs to.")]
    public int? HostId { get; set; }
}
