using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Validation;

// Required accepts a string of spaces, and a name of spaces reaches the column
// and passes the unique index that a second one would then collide with.
[AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
public sealed class NotBlankAttribute() : ValidationAttribute("{0} cannot be blank.")
{
    public override bool IsValid(object? value) =>
        value is not string text || !string.IsNullOrWhiteSpace(text);
}
