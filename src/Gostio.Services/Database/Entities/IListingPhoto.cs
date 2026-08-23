namespace Gostio.Services.Database.Entities;

public interface IListingPhoto : IEntity
{
    byte[] Image { get; set; }

    string ContentType { get; set; }

    bool IsCover { get; set; }

    int DisplayOrder { get; set; }

    DateTime UploadedAt { get; set; }
}
