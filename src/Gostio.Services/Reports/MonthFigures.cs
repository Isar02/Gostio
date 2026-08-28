namespace Gostio.Services.Reports;

internal sealed record MonthCount(int Year, int Month, int Count);

internal sealed record MonthTotal(int Year, int Month, string Currency, decimal Amount);
