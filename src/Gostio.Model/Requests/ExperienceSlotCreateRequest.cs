using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ExperienceSlotCreateRequest
{
    [Required(ErrorMessage = "Choose when the slot starts.")]
    public DateTime? StartTime { get; set; }

    [Required(ErrorMessage = "Say how many people the slot takes.")]
    [Range(1, int.MaxValue, ErrorMessage = "A slot takes at least one person.")]
    public int? Capacity { get; set; }
}
