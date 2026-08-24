using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ExperienceSearchRequest : ListingSearchRequest
{
    public int? CityId { get; set; }

    public int? ExperienceCategoryId { get; set; }

    [Range(0.0, MoneyRules.LargestAmount)]
    public decimal? MinPrice { get; set; }

    [Range(0.0, MoneyRules.LargestAmount)]
    public decimal? MaxPrice { get; set; }

    [Range(1, int.MaxValue)]
    public int? MaxDurationMinutes { get; set; }
}
