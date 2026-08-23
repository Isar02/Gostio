using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public class LookupUpsertRequest
{
    [Required(ErrorMessage = "Enter a name.")]
    [NotBlank(ErrorMessage = "Enter a name.")]
    [StringLength(ColumnLengths.Name, ErrorMessage = "A name is at most {1} characters long.")]
    public string Name { get; set; } = null!;
}
