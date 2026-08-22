using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ForgotPasswordRequest
{
    [Required(ErrorMessage = "Enter the email address on the account.")]
    [EmailAddress(ErrorMessage = "This is not an email address.")]
    public string Email { get; set; } = null!;
}
