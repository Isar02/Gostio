using System.ComponentModel.DataAnnotations;

namespace Gostio.API.Controllers;

// Bound here rather than in the model project, because a posted form is
// something only the API layer knows about.
public sealed class AccommodationPhotoUpload
{
    [Required(ErrorMessage = "Choose an image to upload.")]
    public IFormFile File { get; set; } = null!;
}
