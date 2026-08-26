using Gostio.Model.Requests;

namespace Gostio.API.Controllers;

internal static class FormFileExtensions
{
    public static async Task<ImageUpload> ToImageUploadAsync(
        this IFormFile file,
        CancellationToken cancellationToken)
    {
        using var buffer = new MemoryStream();

        await file.CopyToAsync(buffer, cancellationToken);

        return new ImageUpload(buffer.ToArray(), file.ContentType);
    }
}
