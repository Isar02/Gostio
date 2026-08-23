using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class UserStateRequest
{
    [Required(ErrorMessage = "Say whether the account is active.")]
    public bool? IsActive { get; set; }
}
