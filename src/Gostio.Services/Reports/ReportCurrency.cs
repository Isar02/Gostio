using Gostio.Model.Exceptions;

namespace Gostio.Services.Reports;

public static class ReportCurrency
{
    // Read off the money the report actually summed rather than off the
    // configuration, or a range of euros gets a column heading in marks the
    // moment the configured currency changes. Two currencies inside one range
    // are refused instead of added: nothing sensible comes of the sum, and the
    // administrator can ask for either side of the changeover on its own.
    public static string RequireOne(IEnumerable<string> settled, string whenNothingSettled)
    {
        var found = settled.Distinct(StringComparer.OrdinalIgnoreCase).Order().ToList();

        if (found.Count == 0)
        {
            return whenNothingSettled;
        }

        if (found.Count > 1)
        {
            throw new BusinessException(
                $"This range holds money in {string.Join(" and ", found)}, and the two cannot "
                    + "be added. Ask for a range that stays inside one currency.");
        }

        return found[0];
    }
}
