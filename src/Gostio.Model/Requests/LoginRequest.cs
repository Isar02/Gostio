using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class LoginRequest
{
    [Required(ErrorMessage = "Enter your username.")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Enter your password.")]
    public string Password { get; set; } = null!;
}
