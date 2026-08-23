using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class UserRolesRequest
{
    [MinLength(1, ErrorMessage = "Give the account at least one role.")]
    public List<string> Roles { get; set; } = [];
}
