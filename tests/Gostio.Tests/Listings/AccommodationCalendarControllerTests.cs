using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// A guest reads this one and nobody writes it. Whose listing it is, and whether
// they may see it at all, stays with the service.
public sealed class AccommodationCalendarControllerTests : IAsyncLifetime
{
    private const string Route = "/api/accommodations/7/calendar";

    private readonly StubCalendar calendar = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IStayCalendarService>(calendar));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task ReadingIsOpenToAnySignedInAccount(string role)
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task ItIsNotReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task TheListingAndTheWindowBothReachTheService()
    {
        await host.SendAsync(
            HttpMethod.Get, $"{Route}?from=2026-09-01&to=2026-09-30", RoleNames.Guest);

        Assert.Equal(7, calendar.LastAccommodationId);
        Assert.Equal(new DateOnly(2026, 9, 1), calendar.LastRequest!.From);
        Assert.Equal(new DateOnly(2026, 9, 30), calendar.LastRequest.To);
    }

    private sealed class StubCalendar : IStayCalendarService
    {
        public int? LastAccommodationId { get; private set; }

        public StayCalendarRequest? LastRequest { get; private set; }

        public Task<IReadOnlyList<StayCalendarDayResponse>> ReadAsync(
            int accommodationId,
            StayCalendarRequest request,
            CancellationToken cancellationToken)
        {
            LastAccommodationId = accommodationId;
            LastRequest = request;

            return Task.FromResult<IReadOnlyList<StayCalendarDayResponse>>(
            [
                new StayCalendarDayResponse
                {
                    Date = new DateOnly(2026, 9, 1),
                    IsBookable = true,
                    Price = 100m,
                },
            ]);
        }
    }
}
