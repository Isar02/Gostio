using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ReservationCancelRequest
{
    [Required(ErrorMessage = "Say why the reservation is being cancelled.")]
    [MaxLength(ColumnLengths.Reason)]
    public string? Reason { get; set; }
}
