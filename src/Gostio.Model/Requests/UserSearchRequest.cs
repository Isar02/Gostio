using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class UserSearchRequest : PagedRequest
{
    [StringLength(ColumnLengths.Name)]
    public string? Name { get; set; }

    [StringLength(ColumnLengths.Username)]
    public string? Username { get; set; }

    [StringLength(ColumnLengths.Email)]
    public string? Email { get; set; }

    [StringLength(ColumnLengths.Name)]
    public string? Role { get; set; }

    public bool? IsActive { get; set; }
}
