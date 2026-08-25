using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reviews;

namespace Gostio.Tests.Reviews;

internal sealed class StubReviews : IReviewService
{
    public ReviewSearchRequest? LastSearch { get; private set; }

    public int? LastRead { get; private set; }

    public int? LastWritten { get; private set; }

    public int? LastUpdated { get; private set; }

    public int? LastDeleted { get; private set; }

    public ReviewUpsertRequest? LastRequest { get; private set; }

    public static ReviewResponse Row(int reservationId) => new()
    {
        Id = 1,
        ReservationId = reservationId,
        GuestId = 42,
        GuestName = "A Guest",
        AccommodationId = 3,
        ListingTitle = "A place by the river",
        Rating = 5,
        Comment = "Everything was as described.",
        CreatedAt = new DateTime(2026, 8, 25, 9, 0, 0, DateTimeKind.Utc),
    };

    public Task<PagedResult<ReviewResponse>> SearchAsync(
        ReviewSearchRequest search,
        CancellationToken cancellationToken)
    {
        LastSearch = search;

        return Task.FromResult(new PagedResult<ReviewResponse>
        {
            Items = [Row(11)],
            Page = search.Page,
            PageSize = search.PageSize,
            TotalCount = 1,
        });
    }

    public Task<ReviewResponse> GetAsync(int reservationId, CancellationToken cancellationToken)
    {
        LastRead = reservationId;

        return Task.FromResult(Row(reservationId));
    }

    public Task<ReviewResponse> WriteAsync(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken)
    {
        LastWritten = reservationId;
        LastRequest = request;

        return Task.FromResult(Row(reservationId));
    }

    public Task<ReviewResponse> UpdateAsync(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken)
    {
        LastUpdated = reservationId;
        LastRequest = request;

        return Task.FromResult(Row(reservationId));
    }

    public Task DeleteAsync(int reservationId, CancellationToken cancellationToken)
    {
        LastDeleted = reservationId;

        return Task.CompletedTask;
    }
}
