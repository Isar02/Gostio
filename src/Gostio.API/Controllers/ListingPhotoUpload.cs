using System.ComponentModel.DataAnnotations;

namespace Gostio.API.Controllers;

public sealed class ListingPhotoUpload
{
    [Required(ErrorMessage = "Choose an image to upload.")]
    public IFormFile File { get; set; } = null!;
}
