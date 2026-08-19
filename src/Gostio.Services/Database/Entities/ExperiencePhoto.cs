namespace Gostio.Services.Database.Entities;

public class ExperiencePhoto
{
    public int Id { get; set; }

    public int ExperienceId { get; set; }

    public Experience Experience { get; set; } = null!;

    public byte[] Image { get; set; } = null!;

    public bool IsCover { get; set; }

    public int DisplayOrder { get; set; }

    public DateTime UploadedAt { get; set; }
}
