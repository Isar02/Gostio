using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class CitySearchRequest : PagedRequest
{
    [StringLength(ColumnLengths.Name)]
    public string? Name { get; set; }

    public int? CountryId { get; set; }
}
