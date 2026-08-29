using Gostio.Model.Validation;

namespace Gostio.Services.Database.Seeding;

internal readonly record struct SeedImage(byte[] Content, string ContentType);

internal static class SeedImages
{
    private const string Prefix = "Gostio.Services.Database.Seeding.Assets.";

    // Keyed without the extension, so a photograph and an illustration can each be
    // stored in the format that suits it and neither the caller nor the file name
    // has to say which.
    private static readonly Dictionary<string, string> Resources = Index();

    public static SeedImage Listing(string slug, int number) => Load($"{slug}-{number}");

    public static SeedImage News(int number) => Load($"news-{number}");

    public static SeedImage Profile(int number) => Load($"profile-{number}");

    private static Dictionary<string, string> Index() =>
        typeof(SeedImages).Assembly.GetManifestResourceNames()
            .Where(name => name.StartsWith(Prefix, StringComparison.Ordinal))
            .ToDictionary(
                name => Path.GetFileNameWithoutExtension(name[Prefix.Length..]),
                name => name,
                StringComparer.OrdinalIgnoreCase);

    private static SeedImage Load(string name)
    {
        var assembly = typeof(SeedImages).Assembly;

        if (!Resources.TryGetValue(name, out var resource))
        {
            throw new InvalidOperationException(
                $"Seed image '{name}' is missing from the embedded resources of "
                + $"{assembly.GetName().Name}.");
        }

        using var stream = assembly.GetManifestResourceStream(resource)!;
        using var buffer = new MemoryStream();
        stream.CopyTo(buffer);

        var content = buffer.ToArray();

        // Read off the bytes by the rule the upload endpoints run, so a seeded row
        // and an uploaded one can never disagree about what they hold.
        return new SeedImage(
            content,
            ImageRules.Detect(content)
                ?? throw new InvalidOperationException(
                    $"Seed image '{name}' is not in a format this application serves."));
    }
}
