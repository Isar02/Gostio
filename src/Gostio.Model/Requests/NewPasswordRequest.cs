using System.ComponentModel.DataAnnotations;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

// A new password and the repeat that guards a typo. An administrator setting
// somebody else's sends this and nothing more; the two paths that prove who is
// asking add the field that proves it.
public class NewPasswordRequest
{
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
