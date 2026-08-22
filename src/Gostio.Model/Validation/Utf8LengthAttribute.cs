using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text;

namespace Gostio.Model.Validation;

[AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
public sealed class Utf8LengthAttribute(int maximumBytes)
    : ValidationAttribute("{0} is at most {1} bytes long once written as UTF-8.")
{
    public int MaximumBytes { get; } = maximumBytes;

    public override string FormatErrorMessage(string name) =>
        string.Format(CultureInfo.CurrentCulture, ErrorMessageString, name, MaximumBytes);

    public override bool IsValid(object? value) =>
        value is not string text || Encoding.UTF8.GetByteCount(text) <= MaximumBytes;
}
