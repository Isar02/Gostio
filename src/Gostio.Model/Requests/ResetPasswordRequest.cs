using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ResetPasswordRequest : NewPasswordRequest
{
    [Required(ErrorMessage = "Enter the code from the email.")]
    public string Token { get; set; } = null!;
}
