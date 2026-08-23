using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public abstract class ExperienceUpsertRequest
{
    [Required(ErrorMessage = "Enter a title.")]
    [NotBlank(ErrorMessage = "Enter a title.")]
    [StringLength(ColumnLengths.Title, ErrorMessage = "A title is at most {1} characters long.")]
    public string Title { get; set; } = null!;

    [Required(ErrorMessage = "Enter a description.")]
    [NotBlank(ErrorMessage = "Enter a description.")]
    [StringLength(
        ColumnLengths.Description,
        ErrorMessage = "A description is at most {1} characters long.")]
    public string Description { get; set; } = null!;

    [Range(1, int.MaxValue, ErrorMessage = "Choose the category this experience belongs to.")]
    public int ExperienceCategoryId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Choose the city this experience takes place in.")]
    public int CityId { get; set; }

    [Required(ErrorMessage = "Enter a meeting point.")]
    [NotBlank(ErrorMessage = "Enter a meeting point.")]
    [StringLength(
        ColumnLengths.Address,
        ErrorMessage = "A meeting point is at most {1} characters long.")]
    public string MeetingPoint { get; set; } = null!;

    // The double overload, because the int one would truncate 90.7 to 90 and
    // then find it in range.
    [Range(-90.0, 90.0, ErrorMessage = "A latitude is between {1} and {2}.")]
    public decimal Latitude { get; set; }

    [Range(-180.0, 180.0, ErrorMessage = "A longitude is between {1} and {2}.")]
    public decimal Longitude { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "An experience lasts at least a minute.")]
    public int DurationMinutes { get; set; }

    [Range(
        MoneyRules.SmallestAmount,
        MoneyRules.LargestAmount,
        ErrorMessage = "A price per person is between {1} and {2}.")]
    public decimal PricePerPerson { get; set; }
}
