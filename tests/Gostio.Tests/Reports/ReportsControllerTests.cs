using System.Net;
using Gostio.Model.Authorization;
using Gostio.Services.Reports;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Reports;

public sealed class ReportsControllerTests : IAsyncLifetime
{
    private const string Revenue = "/api/reports/revenue?from=2026-01-01&to=2026-03-31";

    private readonly StubReports reports = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services => services.AddSingleton<IReportService>(reports));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    public async Task AReportIsClosedToEverybodyButAnAdministrator(string role)
    {
        var response = await host.SendAsync(HttpMethod.Get, Revenue, role);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Null(reports.LastRange);
    }

    [Fact]
    public async Task NoReportIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Revenue);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task AnAdministratorAsksOnceAndTheDatesReachTheServiceAsSent()
    {
        var response = await host.SendAsync(HttpMethod.Get, Revenue, RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(new DateOnly(2026, 1, 1), reports.LastRange!.From);
        Assert.Equal(new DateOnly(2026, 3, 31), reports.LastRange.To);
    }

    // The service is what refuses an unusable range, so an absent date has to
    // arrive there rather than being turned away by model binding.
    [Fact]
    public async Task ARequestWithNoDatesStillReachesTheService()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, "/api/reports/revenue", RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Null(reports.LastRange!.From);
    }
}
