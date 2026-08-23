using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ReservationStatusUpsertRequest : LookupUpsertRequest
{
    [Required(ErrorMessage = "Enter a code.")]
    [NotBlank(ErrorMessage = "Enter a code.")]
    [StringLength(ColumnLengths.Code, ErrorMessage = "A code is at most {1} characters long.")]
    public string Code { get; set; } = null!;

    [StringLength(ColumnLengths.Description)]
    public string? Description { get; set; }
}
