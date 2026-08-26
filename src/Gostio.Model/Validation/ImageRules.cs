using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.Model.Validation;

public static class ImageRules
{
    public const int MaximumBytes = 4 * 1024 * 1024;

    public const string Jpeg = "image/jpeg";

    public const string Png = "image/png";

    public const string Webp = "image/webp";

    // What a client sends when it did not look at the file, so it is the
    // absence of a claim rather than a wrong one.
    public const string Unknown = "application/octet-stream";

    public static IReadOnlyList<string> Allowed { get; } = [Jpeg, Png, Webp];

    public static string? Detect(ReadOnlySpan<byte> content)
    {
        if (content.Length >= 3 && content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF)
        {
            return Jpeg;
        }

        if (content.Length >= 8 && content[..8].SequenceEqual(PngSignature))
        {
            return Png;
        }

        if (content.Length >= 12
            && content[..4].SequenceEqual("RIFF"u8)
            && content[8..12].SequenceEqual("WEBP"u8))
        {
            return Webp;
        }

        return null;
    }

    public static string RequireImage(ImageUpload upload, string field)
    {
        if (upload.Content.Length == 0)
        {
            throw new ValidationException(field, "Choose an image to upload.");
        }

        if (upload.Content.Length > MaximumBytes)
        {
            throw new ValidationException(
                field, $"An image is at most {MaximumBytes / (1024 * 1024)} MB.");
        }

        var detected = Detect(upload.Content)
            ?? throw new ValidationException(
                field, $"An image has to be one of {string.Join(", ", Allowed)}.");

        // The claim is checked and then dropped: what reaches the column is
        // what the bytes proved, so a stored type holds on the way back out.
        var claimed = Claimed(upload.ContentType);

        if (claimed is not null
            && !string.Equals(claimed, detected, StringComparison.OrdinalIgnoreCase))
        {
            throw new ValidationException(
                field, $"This file was sent as {claimed} and its bytes say {detected}.");
        }

        return detected;
    }

    private static string? Claimed(string? contentType)
    {
        var named = contentType?.Split(';')[0].Trim();

        return string.IsNullOrEmpty(named)
            || string.Equals(named, Unknown, StringComparison.OrdinalIgnoreCase)
                ? null
                : named;
    }

    private static ReadOnlySpan<byte> PngSignature =>
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
}
