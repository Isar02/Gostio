using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class CountryUpsertRequest : LookupUpsertRequest
{
    [Required(ErrorMessage = "Enter the two letter country code.")]
    [RegularExpression("^[A-Za-z]{2}$", ErrorMessage = "A country code is two letters.")]
    public string IsoCode { get; set; } = null!;
}
