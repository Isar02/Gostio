using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

// The whole set arrives at once and replaces what the listing held. An empty
// list is a listing that offers nothing, which is why only the field is
// required and not its length.
public sealed class AccommodationAmenitiesRequest
{
    [Required(ErrorMessage = "Send the amenities this accommodation offers.")]
    public List<int>? AmenityIds { get; set; }
}
