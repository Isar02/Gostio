using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Services.Reports;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Reports;

public sealed class ReportsControllerTests : IAsyncLifetime
{
    private const string Revenue = "/api/reports/revenue?from=2026-01-01&to=2026-03-31";

    private const string Listings =
        "/api/reports/listings?from=2026-01-01&to=2026-03-31&target=Experiences";

    private const string MyRevenue = "/api/reports/mine/revenue?from=2026-01-01&to=2026-03-31";

    private const string MyListings =
        "/api/reports/mine/listings?from=2026-01-01&to=2026-03-31&target=Experiences";

    private readonly StubReports reports = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services => services.AddSingleton<IReportService>(reports));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest, Revenue)]
    [InlineData(RoleNames.Guest, Listings)]
    [InlineData(RoleNames.Host, Revenue)]
    [InlineData(RoleNames.Host, Listings)]
    public async Task AReportIsClosedToEverybodyButAnAdministrator(string role, string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, role);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Null(reports.LastRange);
        Assert.Null(reports.LastListings);
    }

    [Theory]
    [InlineData(RoleNames.Guest, MyRevenue)]
    [InlineData(RoleNames.Guest, MyListings)]
    [InlineData(RoleNames.Administrator, MyRevenue)]
    [InlineData(RoleNames.Administrator, MyListings)]
    public async Task AHostsOwnReportIsClosedToEverybodyButAHost(string role, string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, role);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.False(reports.AskedForMine);
    }

    [Theory]
    [InlineData(MyRevenue)]
    [InlineData(MyListings)]
    public async Task AHostReachesTheirOwnReport(string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, RoleNames.Host);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(reports.AskedForMine);
    }

    [Fact]
    public async Task AnAccountHoldingBothRolesReachesBothFamilies()
    {
        string[] both = [RoleNames.Administrator, RoleNames.Host];

        var platform = await host.SendAsync(HttpMethod.Get, Revenue, both);
        var mine = await host.SendAsync(HttpMethod.Get, MyRevenue, both);

        Assert.Equal(HttpStatusCode.OK, platform.StatusCode);
        Assert.Equal(HttpStatusCode.OK, mine.StatusCode);
    }

    [Theory]
    [InlineData(Revenue)]
    [InlineData(Listings)]
    public async Task ThePlatformRoutesNeverAskForTheHostScopedDocument(string path)
    {
        await host.SendAsync(HttpMethod.Get, path, RoleNames.Administrator);

        Assert.False(reports.AskedForMine);
    }

    [Theory]
    [InlineData(Revenue)]
    [InlineData(Listings)]
    [InlineData(MyRevenue)]
    [InlineData(MyListings)]
    public async Task NoReportIsReachableWithoutAToken(string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task TheCatalogueIsNamedRatherThanNumberedOnTheWayIn()
    {
        var response = await host.SendAsync(HttpMethod.Get, Listings, RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(SearchTarget.Experiences, reports.LastListings!.Target);
        Assert.Equal(new DateOnly(2026, 1, 1), reports.LastListings.From);
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
