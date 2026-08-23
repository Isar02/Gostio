using System.ComponentModel.DataAnnotations;

namespace Gostio.API.Controllers;

public sealed class AccommodationPhotoUpload
{
    [Required(ErrorMessage = "Choose an image to upload.")]
    public IFormFile File { get; set; } = null!;
}
