using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public abstract class AccommodationUpsertRequest
{
    [Required(ErrorMessage = "Enter a title.")]
    [NotBlank(ErrorMessage = "Enter a title.")]
    [StringLength(ColumnLengths.Title, ErrorMessage = "A title is at most {1} characters long.")]
    public string Title { get; set; } = null!;

    [Required(ErrorMessage = "Enter a description.")]
    [NotBlank(ErrorMessage = "Enter a description.")]
    [StringLength(
        ColumnLengths.Description,
        ErrorMessage = "A description is at most {1} characters long.")]
    public string Description { get; set; } = null!;

    [Range(1, int.MaxValue, ErrorMessage = "Choose the type of accommodation.")]
    public int AccommodationTypeId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Choose the category this accommodation belongs to.")]
    public int AccommodationCategoryId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Choose the city this accommodation is in.")]
    public int CityId { get; set; }

    [Required(ErrorMessage = "Enter an address.")]
    [NotBlank(ErrorMessage = "Enter an address.")]
    [StringLength(ColumnLengths.Address, ErrorMessage = "An address is at most {1} characters long.")]
    public string Address { get; set; } = null!;

    // The double overload, because the int one would truncate 90.7 to 90 and
    // then find it in range.
    [Range(-90.0, 90.0, ErrorMessage = "A latitude is between {1} and {2}.")]
    public decimal Latitude { get; set; }

    [Range(-180.0, 180.0, ErrorMessage = "A longitude is between {1} and {2}.")]
    public decimal Longitude { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "An accommodation takes at least one guest.")]
    public int MaxGuests { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "A bedroom count is zero or more.")]
    public int Bedrooms { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "A bathroom count is zero or more.")]
    public int Bathrooms { get; set; }

    [Range(
        MoneyRules.SmallestAmount,
        MoneyRules.LargestAmount,
        ErrorMessage = "A nightly price is between {1} and {2}.")]
    public decimal PricePerNight { get; set; }

    [Range(0.0, MoneyRules.LargestAmount, ErrorMessage = "A cleaning fee is between {1} and {2}.")]
    public decimal CleaningFee { get; set; }
}
