using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class AccommodationSearchRequest : ListingSearchRequest
{
    public int? CityId { get; set; }

    public int? AccommodationTypeId { get; set; }

    public int? AccommodationCategoryId { get; set; }

    [Range(0.0, MoneyRules.LargestAmount)]
    public decimal? MinPrice { get; set; }

    [Range(0.0, MoneyRules.LargestAmount)]
    public decimal? MaxPrice { get; set; }

    [Range(1, int.MaxValue)]
    public int? MinGuests { get; set; }

    // Every named amenity has to be there, not any of them: a guest who asks
    // for parking and a cot is naming two things they will not do without.
    public List<int>? AmenityIds { get; set; }
}
