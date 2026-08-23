using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public class LookupSearchRequest : PagedRequest
{
    [StringLength(ColumnLengths.Name)]
    public string? Name { get; set; }
}
