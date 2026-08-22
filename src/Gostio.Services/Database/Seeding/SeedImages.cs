using System.Reflection;

namespace Gostio.Services.Database.Seeding;

internal static class SeedImages
{
    private const string Prefix = "Gostio.Services.Database.Seeding.Assets.";

    public static byte[] Accommodation(int index) => Load($"accommodation{Wrap(index, 12):00}.jpg");

    public static byte[] Experience(int index) => Load($"experience{Wrap(index, 8):00}.jpg");

    public static byte[] News(int index) => Load($"news{Wrap(index, 4):00}.jpg");

    public static byte[] Profile(int index) => Load($"profile{Wrap(index, 6):00}.jpg");

    private static int Wrap(int index, int count) => ((index - 1) % count) + 1;

    private static byte[] Load(string fileName)
    {
        var assembly = typeof(SeedImages).Assembly;

        using var stream = assembly.GetManifestResourceStream(Prefix + fileName)
            ?? throw new InvalidOperationException(
                $"Seed image '{fileName}' is missing from the embedded resources of "
                + $"{assembly.GetName().Name}.");

        using var buffer = new MemoryStream();
        stream.CopyTo(buffer);

        return buffer.ToArray();
    }
}
