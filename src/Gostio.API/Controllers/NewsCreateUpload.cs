using System.ComponentModel.DataAnnotations;
using Gostio.Model.Requests;

namespace Gostio.API.Controllers;

public sealed class NewsCreateUpload : NewsUpsertRequest
{
    [Required(ErrorMessage = "Choose an image to upload.")]
    public IFormFile File { get; set; } = null!;
}
