using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

// One exception to an otherwise open calendar. Both dates are inclusive, the
// way a host reads a calendar.
public sealed class AccommodationAvailabilityRequest
{
    [Required(ErrorMessage = "Choose the first day of the range.")]
    public DateOnly? StartDate { get; set; }

    [Required(ErrorMessage = "Choose the last day of the range.")]
    public DateOnly? EndDate { get; set; }

    // Absent rather than false by default: blocking the dates and repricing
    // them are opposite answers, and a client that omitted this said neither.
    [Required(ErrorMessage = "Say whether the range is open for booking.")]
    public bool? IsAvailable { get; set; }

    [Range(
        MoneyRules.SmallestAmount,
        MoneyRules.LargestAmount,
        ErrorMessage = "A nightly price is between {1} and {2}.")]
    public decimal? PriceOverride { get; set; }
}
