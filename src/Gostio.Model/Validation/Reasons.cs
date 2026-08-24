namespace Gostio.Model.Validation;

public static class Reasons
{
    // A processor writes the message, not this application, so it arrives at
    // whatever length it likes and is cut to the column rather than refused:
    // losing the tail of an explanation beats losing the row that carries it.
    public static string? Fit(string? reason)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            return null;
        }

        var trimmed = reason.Trim();

        return trimmed.Length <= ColumnLengths.Reason
            ? trimmed
            : trimmed[..ColumnLengths.Reason];
    }
}
