using System.ComponentModel.DataAnnotations;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ResetPasswordRequest
{
    [Required(ErrorMessage = "This reset link carries no token.")]
    public string Token { get; set; } = null!;

    [Required(ErrorMessage = "Enter a new password.")]
    [MinLength(
        PasswordRules.MinimumLength,
        ErrorMessage = "A password is at least {1} characters long.")]
    [Utf8Length(PasswordRules.MaximumBytes)]
    public string NewPassword { get; set; } = null!;

    [Required(ErrorMessage = "Repeat the new password.")]
    [Compare(nameof(NewPassword), ErrorMessage = "The two passwords do not match.")]
    public string ConfirmNewPassword { get; set; } = null!;
}
