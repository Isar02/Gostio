using System.ComponentModel.DataAnnotations;
using Gostio.Model.Validation;

namespace Gostio.Model.Requests;

public sealed class ReviewSearchRequest : PagedRequest
{
    public int? AccommodationId { get; set; }

    public int? ExperienceId { get; set; }

    public int? HostId { get; set; }

    public int? GuestId { get; set; }

    [Range(ReviewRatings.Lowest, ReviewRatings.Highest)]
    public int? MinRating { get; set; }

    [Range(ReviewRatings.Lowest, ReviewRatings.Highest)]
    public int? MaxRating { get; set; }
}
