using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

// The username is absent on purpose: the account is known by it, and the roles
// and the activation are the administrator's alone and have endpoints of their
// own.
public sealed class UserUpdateRequest
{
    [Required(ErrorMessage = "Enter a first name.")]
    [NotBlank(ErrorMessage = "Enter a first name.")]
    [StringLength(ColumnLengths.Name)]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "Enter a last name.")]
    [NotBlank(ErrorMessage = "Enter a last name.")]
    [StringLength(ColumnLengths.Name)]
    public string LastName { get; set; } = null!;

    [Required(ErrorMessage = "Enter an email address.")]
    [EmailAddress(ErrorMessage = "This is not an email address.")]
    [StringLength(ColumnLengths.Email)]
    public string Email { get; set; } = null!;

    [StringLength(ColumnLengths.PhoneNumber)]
    public string? PhoneNumber { get; set; }
}
