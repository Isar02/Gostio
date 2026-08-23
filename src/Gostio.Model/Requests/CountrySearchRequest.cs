using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class CountrySearchRequest : LookupSearchRequest
{
    [StringLength(ColumnLengths.IsoCode)]
    public string? IsoCode { get; set; }
}
