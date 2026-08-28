using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class UserCreateRequest : AccountCreateRequest
{
    [Required(ErrorMessage = "Give the account at least one role.")]
    [MinLength(1, ErrorMessage = "Give the account at least one role.")]
    public List<string> Roles { get; set; } = [];
}
