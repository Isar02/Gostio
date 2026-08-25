using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ReviewUpsertRequest
{
    [Required(ErrorMessage = "Give what you booked a rating.")]
    [Range(
        ReviewRatings.Lowest,
        ReviewRatings.Highest,
        ErrorMessage = "A rating is between {1} and {2}.")]
    public int? Rating { get; set; }

    [StringLength(
        ColumnLengths.Comment,
        ErrorMessage = "A comment is at most {1} characters long.")]
    public string? Comment { get; set; }
}
