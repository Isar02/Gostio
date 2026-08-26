using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class NewsSearchRequest : PagedRequest
{
    [StringLength(ColumnLengths.Title)]
    public string? Title { get; set; }

    public DateTime? PublishedFrom { get; set; }

    public DateTime? PublishedTo { get; set; }
}
