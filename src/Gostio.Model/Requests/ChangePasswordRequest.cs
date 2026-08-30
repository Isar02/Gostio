using System.ComponentModel.DataAnnotations;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ChangePasswordRequest : NewPasswordRequest
{
    [Required(ErrorMessage = "Enter your current password.")]
    [Utf8Length(PasswordRules.MaximumBytes)]
    public string CurrentPassword { get; set; } = null!;
}
