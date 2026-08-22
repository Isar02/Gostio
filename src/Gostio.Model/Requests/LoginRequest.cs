using System.ComponentModel.DataAnnotations;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Enter your username.")]
    public string Username { get; set; } = null!;

    // Bounded but not floored: bcrypt reads no further than this, and a seeded
    // account signs in with fewer characters than a new password may have.
    [Required(ErrorMessage = "Enter your password.")]
    [Utf8Length(PasswordRules.MaximumBytes)]
    public string Password { get; set; } = null!;
}
