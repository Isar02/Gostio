using System.ComponentModel.DataAnnotations;
using Gostio.Model.Authorization;

namespace Gostio.Model.Requests;

public sealed class ChangePasswordRequest
{
    [Required(ErrorMessage = "Enter your current password.")]
    public string CurrentPassword { get; set; } = null!;

    [Required(ErrorMessage = "Enter a new password.")]
    [StringLength(
        PasswordRules.MaximumLength,
        MinimumLength = PasswordRules.MinimumLength,
        ErrorMessage = "A password is between {2} and {1} characters long.")]
    public string NewPassword { get; set; } = null!;

    [Required(ErrorMessage = "Repeat the new password.")]
    [Compare(nameof(NewPassword), ErrorMessage = "The two passwords do not match.")]
    public string ConfirmNewPassword { get; set; } = null!;
}
