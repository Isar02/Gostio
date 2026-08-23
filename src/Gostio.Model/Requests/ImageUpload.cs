namespace Gostio.Model.Requests;

public sealed record ImageUpload(byte[] Content, string? ContentType);
