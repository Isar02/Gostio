using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

// Nullable so that an absent list and an empty one stay different answers: the
// first is refused, the second clears the set.
public sealed class AccommodationAmenitiesRequest
{
    [Required(ErrorMessage = "Send the amenities this accommodation offers.")]
    public List<int>? AmenityIds { get; set; }
}
