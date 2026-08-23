using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class AccommodationSearchRequest : PagedRequest
{
    [StringLength(ColumnLengths.Title)]
    public string? Title { get; set; }

    public int? CityId { get; set; }

    public int? AccommodationTypeId { get; set; }

    public int? AccommodationCategoryId { get; set; }

    public int? HostId { get; set; }

    [Range(0.0, MoneyRules.LargestAmount)]
    public decimal? MinPrice { get; set; }

    [Range(0.0, MoneyRules.LargestAmount)]
    public decimal? MaxPrice { get; set; }

    [Range(1, int.MaxValue)]
    public int? MinGuests { get; set; }

    public bool? IsActive { get; set; }
}
