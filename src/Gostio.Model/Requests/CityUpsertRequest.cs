using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class CityUpsertRequest
{
    [Required(ErrorMessage = "Enter a name.")]
    [NotBlank(ErrorMessage = "Enter a name.")]
    [StringLength(ColumnLengths.Name, ErrorMessage = "A name is at most {1} characters long.")]
    public string Name { get; set; } = null!;

    [Range(1, int.MaxValue, ErrorMessage = "Choose the country this city is in.")]
    public int CountryId { get; set; }
}
