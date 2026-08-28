using Gostio.Model.Exceptions;
using Gostio.Services.Reports;

namespace Gostio.Tests.Reports;

public class ReportCurrencyTests
{
    private const string Configured = "eur";

    [Fact]
    public void MoneyInOneCurrencyLabelsTheReportWithIt()
    {
        Assert.Equal("bam", ReportCurrency.RequireOne(["bam"], Configured));
    }

    [Fact]
    public void ARangeThatSettledNothingFallsBackToTheConfiguredCurrency()
    {
        Assert.Equal(Configured, ReportCurrency.RequireOne([], Configured));
    }

    // Adding them is the one thing that must not happen, and labelling the sum
    // with either of the two is how it would go unnoticed.
    [Fact]
    public void TwoCurrenciesAreRefusedAndTheMessageNamesBoth()
    {
        var refused = Assert.Throws<BusinessException>(
            () => ReportCurrency.RequireOne(["eur", "bam"], Configured));

        Assert.Contains("bam", refused.Message);
        Assert.Contains("eur", refused.Message);
    }
}
