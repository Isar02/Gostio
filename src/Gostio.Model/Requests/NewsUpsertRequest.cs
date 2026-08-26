using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public class NewsUpsertRequest
{
    [Required(ErrorMessage = "Enter a title.")]
    [NotBlank(ErrorMessage = "Enter a title.")]
    [StringLength(ColumnLengths.Title, ErrorMessage = "A title is at most {1} characters long.")]
    public string Title { get; set; } = null!;

    [Required(ErrorMessage = "Enter the text.")]
    [NotBlank(ErrorMessage = "Enter the text.")]
    [StringLength(ColumnLengths.NewsBody, ErrorMessage = "A text is at most {1} characters long.")]
    public string Body { get; set; } = null!;
}
