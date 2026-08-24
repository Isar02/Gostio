using System.ComponentModel.DataAnnotations;

namespace Gostio.Model.Requests;

public sealed class ExperienceCreateRequest : ExperienceUpsertRequest
{
    // Absent means the caller keeps the experience; an administrator names a
    // host instead, because they are not the one running it.
    [Range(1, int.MaxValue, ErrorMessage = "Choose the host this experience belongs to.")]
    public int? HostId { get; set; }
}
