using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public abstract class ListingSearchRequest : PagedRequest
{
    [StringLength(ColumnLengths.Title)]
    public string? Title { get; set; }

    public int? HostId { get; set; }

    public bool? IsActive { get; set; }
}
