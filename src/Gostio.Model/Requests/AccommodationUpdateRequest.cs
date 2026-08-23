using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class AccommodationUpdateRequest : AccommodationUpsertRequest
{
    [Required(ErrorMessage = "Say whether the listing is published.")]
    public bool? IsActive { get; set; }
}
