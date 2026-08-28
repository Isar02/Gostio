using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Validation;

[AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
public sealed class PhoneNumberAttribute() : ValidationAttribute(PhoneNumbers.Message)
{
    public override bool IsValid(object? value) =>
        value is not string text || PhoneNumbers.IsValid(text);
}
