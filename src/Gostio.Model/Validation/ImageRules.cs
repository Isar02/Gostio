namespace Gostio.Model.Validation;

public static class ImageRules
{
    public const int MaximumBytes = 4 * 1024 * 1024;

    public const string Jpeg = "image/jpeg";

    public const string Png = "image/png";

    public const string Webp = "image/webp";

    public static IReadOnlyList<string> Allowed { get; } = [Jpeg, Png, Webp];

    // What the bytes say rather than what the upload claimed. A content type is
    // a header the caller writes, and a stored one has to hold on the way out.
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

    private static ReadOnlySpan<byte> PngSignature =>
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
}
