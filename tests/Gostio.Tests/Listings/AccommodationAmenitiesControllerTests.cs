using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// The amenities follow the listing: anybody signed in may read the set, and
// only a host or an administrator may replace it. Whose listing it is stays
// with the service.
public sealed class AccommodationAmenitiesControllerTests : IAsyncLifetime
{
    private const string Route = "/api/accommodations/7/amenities";

    private readonly StubAmenities amenities = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IAccommodationAmenityService>(amenities));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Fact]
    public async Task ReadingIsOpenToAnySignedInAccount()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task WritingIsClosedToAGuest()
    {
        var response = await host.SendAsync(HttpMethod.Put, Route, RoleNames.Guest, Body());

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task AHostAndAnAdministratorBothReachTheWrite(string role)
    {
        var response = await host.SendAsync(HttpMethod.Put, Route, role, Body());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheSetAndTheListingBothReachTheService()
    {
        await host.SendAsync(HttpMethod.Put, Route, RoleNames.Host, Body());

        Assert.Equal([4, 9], amenities.LastRequest!.AmenityIds);
        Assert.Equal(7, amenities.LastAccommodationId);
    }

    [Fact]
    public async Task AnAbsentListIsRefusedBeforeTheServiceIsReached()
    {
        var response = await host.SendAsync(
            HttpMethod.Put, Route, RoleNames.Host, new AccommodationAmenitiesRequest());

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(amenities.LastRequest);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static AccommodationAmenitiesRequest Body() => new() { AmenityIds = [4, 9] };

    private sealed class StubAmenities : IAccommodationAmenityService
    {
        public AccommodationAmenitiesRequest? LastRequest { get; private set; }

        public int? LastAccommodationId { get; private set; }

        public Task<PagedResult<LookupResponse>> GetAsync(
            int accommodationId,
            PagedRequest request,
            CancellationToken cancellationToken) =>
            Task.FromResult(new PagedResult<LookupResponse>
            {
                Items = [Row(4)],
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = 1,
            });

        public Task<IReadOnlyList<LookupResponse>> SetAsync(
            int accommodationId,
            AccommodationAmenitiesRequest request,
            CancellationToken cancellationToken)
        {
            LastAccommodationId = accommodationId;
            LastRequest = request;

            return Task.FromResult<IReadOnlyList<LookupResponse>>([Row(4), Row(9)]);
        }

        private static LookupResponse Row(int id) => new() { Id = id, Name = $"Amenity {id}" };
    }
}
