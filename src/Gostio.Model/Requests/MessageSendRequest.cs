using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class MessageSendRequest
{
    [Required(ErrorMessage = "A message needs something in it.")]
    [NotBlank(ErrorMessage = "A message needs something in it.")]
    [StringLength(
        ColumnLengths.MessageBody,
        ErrorMessage = "A message is at most {1} characters long.")]
    public string? Body { get; set; }
}
