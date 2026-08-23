namespace Gostio.Model.Responses;

// The bytes are absent on purpose: this is what a gallery needs to lay itself
// out, and the image itself comes from the endpoint serving one photo.
public sealed class ListingPhotoResponse : IIdentified
{
    public required int Id { get; init; }

    public required int ListingId { get; init; }

    public required string ContentType { get; init; }

    public required bool IsCover { get; init; }

    public required int DisplayOrder { get; init; }

    public required int SizeInBytes { get; init; }

    public required DateTime UploadedAt { get; init; }
}
