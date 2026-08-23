using System.ComponentModel.DataAnnotations;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class UserCreateRequest
{
    [Required(ErrorMessage = "Enter a first name.")]
    [NotBlank(ErrorMessage = "Enter a first name.")]
    [StringLength(ColumnLengths.Name)]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "Enter a last name.")]
    [NotBlank(ErrorMessage = "Enter a last name.")]
    [StringLength(ColumnLengths.Name)]
    public string LastName { get; set; } = null!;

    [Required(ErrorMessage = "Enter a username.")]
    [StringLength(ColumnLengths.Username)]
    [RegularExpression(
        "^[A-Za-z0-9._-]+$",
        ErrorMessage = "A username holds letters, digits, dots, dashes and underscores.")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Enter an email address.")]
    [EmailAddress(ErrorMessage = "This is not an email address.")]
    [StringLength(ColumnLengths.Email)]
    public string Email { get; set; } = null!;

    [StringLength(ColumnLengths.PhoneNumber)]
    public string? PhoneNumber { get; set; }

    [Required(ErrorMessage = "Enter a password.")]
    [MinLength(
        PasswordRules.MinimumLength,
        ErrorMessage = "A password is at least {1} characters long.")]
    [Utf8Length(PasswordRules.MaximumBytes)]
    public string Password { get; set; } = null!;

    [Required(ErrorMessage = "Repeat the password.")]
    [Compare(nameof(Password), ErrorMessage = "The two passwords do not match.")]
    public string ConfirmPassword { get; set; } = null!;

    [MinLength(1, ErrorMessage = "Give the account at least one role.")]
    public List<string> Roles { get; set; } = [];
}
