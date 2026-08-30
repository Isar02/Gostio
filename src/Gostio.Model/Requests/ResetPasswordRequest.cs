using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ResetPasswordRequest : NewPasswordRequest
{
    [Required(ErrorMessage = "This reset link carries no token.")]
    public string Token { get; set; } = null!;
}
