namespace Gostio.Services.Database.Entities;

public class AccommodationPhoto : IListingPhoto
{
    public int Id { get; set; }

    public int AccommodationId { get; set; }

    public Accommodation Accommodation { get; set; } = null!;

    public byte[] Image { get; set; } = null!;

    public string ContentType { get; set; } = null!;

    public bool IsCover { get; set; }

    public int DisplayOrder { get; set; }

    public DateTime UploadedAt { get; set; }
}
