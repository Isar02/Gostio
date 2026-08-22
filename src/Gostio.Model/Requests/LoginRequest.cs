using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

// Not required members: a missing property would then fail deserialization with
// an exception the client is never shown, instead of the message written here.
public sealed class LoginRequest
{
    [Required(ErrorMessage = "Enter your username.")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Enter your password.")]
    public string Password { get; set; } = null!;
}
