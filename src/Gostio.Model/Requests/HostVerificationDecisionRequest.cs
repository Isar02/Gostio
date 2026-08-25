using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class HostVerificationDecisionRequest
{
    [StringLength(
        ColumnLengths.Reason,
        ErrorMessage = "A reason is at most {1} characters long.")]
    public string? Reason { get; set; }
}
