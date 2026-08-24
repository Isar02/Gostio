using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ExperienceSlotUpdateRequest
{
    [Required(ErrorMessage = "Say how many people the slot takes.")]
    [Range(1, int.MaxValue, ErrorMessage = "A slot takes at least one person.")]
    public int? Capacity { get; set; }

    // Absent rather than false by default: closing a term and leaving it open
    // are opposite answers, and a client that omitted this said neither.
    [Required(ErrorMessage = "Say whether the slot is open for booking.")]
    public bool? IsActive { get; set; }
}
