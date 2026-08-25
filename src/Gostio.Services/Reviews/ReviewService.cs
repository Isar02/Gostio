using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reviews;

internal sealed class ReviewService(
    GostioDbContext db,
    ICurrentUser currentUser,
    ReservationAccess reservations) : IReviewService
{
    private static Expression<Func<Review, ReviewResponse>> Projection =>
        review => new ReviewResponse
        {
            Id = review.Id,
            ReservationId = review.ReservationId,
            GuestId = review.Reservation.UserId,
            GuestName =
                review.Reservation.User.FirstName + " " + review.Reservation.User.LastName,
            AccommodationId = review.Reservation.AccommodationId,
            ExperienceId = review.Reservation.ExperienceSlot != null
                ? (int?)review.Reservation.ExperienceSlot.ExperienceId
                : null,
            ListingTitle = review.Reservation.Accommodation != null
                ? review.Reservation.Accommodation.Title
                : review.Reservation.ExperienceSlot!.Experience.Title,
            Rating = review.Rating,
            Comment = review.Comment,
            CreatedAt = review.CreatedAt,
            ModifiedAt = review.ModifiedAt,
        };

    public Task<PagedResult<ReviewResponse>> SearchAsync(
        ReviewSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(db.Reviews.AsNoTracking(), search)
            .OrderByDescending(review => review.CreatedAt)
            .ThenByDescending(review => review.Id)
            .ToPagedResultAsync(search, Projection, cancellationToken);

    public Task<ReviewResponse> GetAsync(int reservationId, CancellationToken cancellationToken) =>
        ReadAsync(reservationId, cancellationToken);

    public async Task<ReviewResponse> WriteAsync(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var booking = await reservations.RequireReachableAsync(reservationId, cancellationToken);

        RequireTheGuest(booking);
        RequireTheBookingIsOver(booking);

        db.Reviews.Add(new Review
        {
            ReservationId = reservationId,
            Rating = RequiredRating(request),
            Comment = Trimmed(request.Comment),
            CreatedAt = DateTime.UtcNow,
        });

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            throw new BusinessException("This booking has already been reviewed.");
        }

        return await ReadAsync(reservationId, cancellationToken);
    }

    public async Task<ReviewResponse> UpdateAsync(
        int reservationId,
        ReviewUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var booking = await reservations.RequireReachableAsync(reservationId, cancellationToken);

        RequireTheGuest(booking);

        var review = await db.Reviews
            .FirstOrDefaultAsync(row => row.ReservationId == reservationId, cancellationToken)
            ?? throw Missing(reservationId);

        review.Rating = RequiredRating(request);
        review.Comment = Trimmed(request.Comment);
        review.ModifiedAt = DateTime.UtcNow;

        await db.SaveChangesAsync(cancellationToken);

        return await ReadAsync(reservationId, cancellationToken);
    }

    public async Task DeleteAsync(int reservationId, CancellationToken cancellationToken)
    {
        var booking = await reservations.RequireReachableAsync(reservationId, cancellationToken);

        if (currentUser.RequireUserId() != booking.GuestId
            && !currentUser.IsInRole(RoleNames.Administrator))
        {
            throw new ForbiddenException("A review is the guest's to take back.");
        }

        var removed = await db.Reviews
            .Where(review => review.ReservationId == reservationId)
            .ExecuteDeleteAsync(cancellationToken);

        if (removed == 0)
        {
            throw Missing(reservationId);
        }
    }

    private static IQueryable<Review> Matching(IQueryable<Review> query, ReviewSearchRequest search)
    {
        if (search.AccommodationId is int accommodationId)
        {
            query = query.Where(review =>
                review.Reservation.AccommodationId == accommodationId);
        }

        if (search.ExperienceId is int experienceId)
        {
            query = query.Where(review =>
                review.Reservation.ExperienceSlot != null
                && review.Reservation.ExperienceSlot.ExperienceId == experienceId);
        }

        if (search.HostId is int hostId)
        {
            query = query.Where(review =>
                (review.Reservation.Accommodation != null
                    && review.Reservation.Accommodation.HostId == hostId)
                || (review.Reservation.ExperienceSlot != null
                    && review.Reservation.ExperienceSlot.Experience.HostId == hostId));
        }

        if (search.GuestId is int guestId)
        {
            query = query.Where(review => review.Reservation.UserId == guestId);
        }

        if (search.MinRating is int lowest)
        {
            query = query.Where(review => review.Rating >= lowest);
        }

        if (search.MaxRating is int highest)
        {
            query = query.Where(review => review.Rating <= highest);
        }

        return query;
    }

    private async Task<ReviewResponse> ReadAsync(
        int reservationId,
        CancellationToken cancellationToken) =>
        await db.Reviews
            .AsNoTracking()
            .Where(review => review.ReservationId == reservationId)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(reservationId);

    private void RequireTheGuest(ReservationView booking)
    {
        if (currentUser.RequireUserId() != booking.GuestId)
        {
            throw new ForbiddenException("Only the guest who booked says how it was.");
        }
    }

    private static void RequireTheBookingIsOver(ReservationView booking)
    {
        if (ReservationStateMachine.RequireKnown(booking.StatusId)
            != ReservationStatusCode.Completed)
        {
            throw new BusinessException("A booking is reviewed once it is behind the guest.");
        }
    }

    private static int RequiredRating(ReviewUpsertRequest request)
    {
        var rating = request.Rating
            ?? throw new ValidationException(
                nameof(request.Rating), "Give what you booked a rating.");

        if (rating < ReviewRatings.Lowest || rating > ReviewRatings.Highest)
        {
            throw new ValidationException(
                nameof(request.Rating),
                $"A rating is between {ReviewRatings.Lowest} and {ReviewRatings.Highest}.");
        }

        return rating;
    }

    private static string? Trimmed(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static NotFoundException Missing(int reservationId) =>
        new($"Reservation {reservationId} has no review.");
}
