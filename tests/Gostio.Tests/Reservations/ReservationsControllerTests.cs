using System.Net;
using System.Net.Http.Json;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reservations;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Reservations;

// Anybody signed in reaches all of it. Which reservation is theirs, and who may
// confirm one, is the service's answer rather than the route's: the rule names a
// host of one listing, which a role on a token cannot say.
public sealed class ReservationsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/reservations";

    private readonly StubMoves moves = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services =>
        {
            services.AddSingleton<IReservationService>(new StubReservations());
            services.AddSingleton<IReservationMoveService>(moves);
        });

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Fact]
    public async Task ReadingOneIsOpenToAnySignedInAccount()
    {
        var response = await host.SendAsync(HttpMethod.Get, $"{Route}/3", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task BookingAnswersWithTheRouteThatReadsItBack()
    {
        var response = await host.SendAsync(HttpMethod.Post, Route, RoleNames.Guest, ABooking);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal($"{Route}/9", response.Headers.Location?.AbsolutePath);
    }

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task ConfirmingIsReachedByEverySignedInAccount(string role)
    {
        var response = await host.SendAsync(HttpMethod.Post, $"{Route}/3/confirm", role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task CancellingCarriesItsReasonThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Post, $"{Route}/3/cancel", RoleNames.Guest, new { reason = "Plans changed" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Plans changed", moves.LastReason);
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("""{"reason":"   "}""")]
    public async Task ACancellationWithoutAReasonIsRefused(string body)
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            $"{Route}/3/cancel",
            RoleNames.Guest,
            new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var errors = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.Contains(nameof(ReservationCancelRequest.Reason), errors!.Errors!.Keys);
    }

    [Theory]
    [InlineData("GET", $"{Route}/3")]
    [InlineData("POST", $"{Route}/3/confirm")]
    [InlineData("POST", $"{Route}/3/cancel")]
    public async Task NoneOfItIsReachableWithoutAToken(string method, string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static object ABooking => new
    {
        accommodationId = 1,
        checkInDate = "2026-09-01",
        checkOutDate = "2026-09-03",
        guestCount = 2,
    };

    private static ReservationResponse Row(int id) => new()
    {
        Id = id,
        UserId = 42,
        AccommodationId = 1,
        CheckInDate = new DateOnly(2026, 9, 1),
        CheckOutDate = new DateOnly(2026, 9, 3),
        GuestCount = 2,
        ReservationStatusId = (int)ReservationStatusCode.Pending,
        Status = nameof(ReservationStatusCode.Pending),
        ExpiresAt = new DateTime(2026, 8, 25, 12, 0, 0, DateTimeKind.Utc),
        AccommodationTotal = 200m,
        CleaningFee = 15m,
        TotalPrice = 215m,
        CreatedAt = new DateTime(2026, 8, 24, 12, 0, 0, DateTimeKind.Utc),
    };

    private sealed class StubReservations : IReservationService
    {
        public Task<ReservationResponse> CreateAsync(
            ReservationCreateRequest request,
            CancellationToken cancellationToken) => Task.FromResult(Row(9));

        public Task<ReservationResponse> GetAsync(
            int reservationId,
            CancellationToken cancellationToken) => Task.FromResult(Row(reservationId));
    }

    private sealed class StubMoves : IReservationMoveService
    {
        public string? LastReason { get; private set; }

        public Task<ReservationResponse> ConfirmAsync(
            int reservationId,
            CancellationToken cancellationToken) => Task.FromResult(Row(reservationId));

        public Task<ReservationResponse> CancelAsync(
            int reservationId,
            ReservationCancelRequest request,
            CancellationToken cancellationToken)
        {
            LastReason = request.Reason;

            return Task.FromResult(Row(reservationId));
        }
    }
}
