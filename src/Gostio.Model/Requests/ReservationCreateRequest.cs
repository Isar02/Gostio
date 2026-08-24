using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ReservationCreateRequest
{
    public int? AccommodationId { get; set; }

    public int? ExperienceSlotId { get; set; }

    public DateOnly? CheckInDate { get; set; }

    public DateOnly? CheckOutDate { get; set; }

    [Required(ErrorMessage = "Say how many people are coming.")]
    [Range(1, int.MaxValue, ErrorMessage = "A booking is for at least one person.")]
    public int? GuestCount { get; set; }
}
