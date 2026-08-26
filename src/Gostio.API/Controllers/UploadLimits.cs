using Gostio.Model.Validation;

namespace Gostio.API.Controllers;

public static class UploadLimits
{
    private const int LongestTextBytes = (ColumnLengths.Title + ColumnLengths.NewsBody) * 4;

    // Refused before a body is read, which the check on the bytes cannot be, so
    // it has to clear the image, the longest text a form carries beside it at
    // four bytes to the character, and the multipart framing around both.
    public const int Multipart = ImageRules.MaximumBytes + LongestTextBytes + (8 * 1024);
}
