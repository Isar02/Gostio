using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class AccommodationAvailabilityService(
    GostioDbContext db,
    AccommodationAccess access)
    : IAccommodationAvailabilityService
{
    private static Expression<Func<AccommodationAvailability, AccommodationAvailabilityResponse>>
        Projection =>
        range => new AccommodationAvailabilityResponse
        {
            Id = range.Id,
            AccommodationId = range.AccommodationId,
            StartDate = range.StartDate,
            EndDate = range.EndDate,
            IsAvailable = range.IsAvailable,
            PriceOverride = range.PriceOverride,
        };

    public async Task<PagedResult<AccommodationAvailabilityResponse>> SearchAsync(
        int accommodationId,
        AccommodationAvailabilitySearchRequest search,
        CancellationToken cancellationToken)
    {
        await access.RequireVisibleAsync(accommodationId, cancellationToken);

        RequireAWindow(search);

        var query = ForListing(accommodationId).AsNoTracking();

        if (search.From is DateOnly from)
        {
            query = query.Where(range => range.EndDate >= from);
        }

        if (search.To is DateOnly to)
        {
            query = query.Where(range => range.StartDate <= to);
        }

        if (search.IsAvailable is bool isAvailable)
        {
            query = query.Where(range => range.IsAvailable == isAvailable);
        }

        return await query
            .OrderBy(range => range.StartDate)
            .ThenBy(range => range.Id)
            .ToPagedResultAsync(search, Projection, cancellationToken);
    }

    public async Task<AccommodationAvailabilityResponse> GetAsync(
        int accommodationId,
        int availabilityId,
        CancellationToken cancellationToken)
    {
        await access.RequireVisibleAsync(accommodationId, cancellationToken);

        return await ReadAsync(accommodationId, availabilityId, cancellationToken);
    }

    public async Task<AccommodationAvailabilityResponse> AddAsync(
        int accommodationId,
        AccommodationAvailabilityRequest request,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        var range = Validated(accommodationId, request);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // Inside the lock, or two ranges that overlap each other both find the
        // calendar clear and both land on it.
        await access.LockAsync(accommodationId, cancellationToken);

        await RequireTheDatesAreFreeAsync(range, cancellationToken);

        db.AccommodationAvailability.Add(range);

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(accommodationId, range.Id, cancellationToken);
    }

    // A range is edited by removing it and adding the replacement: a host opens
    // and closes dates rather than reshaping a row that is already there.
    public async Task DeleteAsync(
        int accommodationId,
        int availabilityId,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        var removed = await ForRange(accommodationId, availabilityId)
            .ExecuteDeleteAsync(cancellationToken);

        if (removed == 0)
        {
            throw Missing(availabilityId);
        }
    }

    // The two bounds are filters of their own, so an inverted window is not an
    // empty one: it asks for ranges ending after the later day and starting
    // before the earlier, which a long enough range satisfies.
    private static void RequireAWindow(AccommodationAvailabilitySearchRequest search)
    {
        if (search.From is DateOnly from && search.To is DateOnly to && to < from)
        {
            throw new ValidationException(
                nameof(search.To), "A window ends on or after the day it starts.");
        }
    }

    private static AccommodationAvailability Validated(
        int accommodationId,
        AccommodationAvailabilityRequest request)
    {
        var startDate = request.StartDate ?? throw new ValidationException(
            nameof(request.StartDate), "Choose the first day of the range.");

        var endDate = request.EndDate ?? throw new ValidationException(
            nameof(request.EndDate), "Choose the last day of the range.");

        var isAvailable = request.IsAvailable ?? throw new ValidationException(
            nameof(request.IsAvailable), "Say whether the range is open for booking.");

        if (endDate < startDate)
        {
            throw new ValidationException(
                nameof(request.EndDate), "A range ends on or after the day it starts.");
        }

        if (request.PriceOverride is decimal price && price <= 0)
        {
            throw new ValidationException(
                nameof(request.PriceOverride), "A nightly price is above zero.");
        }

        // An open range exists to carry a price, since the calendar is already
        // open without it. A blocked one may keep the price it would charge if
        // it reopened, and does not have to.
        if (isAvailable && request.PriceOverride is null)
        {
            throw new ValidationException(
                nameof(request.PriceOverride),
                "A range that stays open has to carry a nightly price of its own.");
        }

        return new AccommodationAvailability
        {
            AccommodationId = accommodationId,
            StartDate = startDate,
            EndDate = endDate,
            IsAvailable = isAvailable,
            PriceOverride = request.PriceOverride,
        };
    }

    // Both dates are inclusive, so ranges that share a single day overlap and
    // one ending the day before the next begins does not.
    private async Task RequireTheDatesAreFreeAsync(
        AccommodationAvailability range,
        CancellationToken cancellationToken)
    {
        var taken = await ForListing(range.AccommodationId)
            .AsNoTracking()
            .AnyAsync(
                other => other.StartDate <= range.EndDate && range.StartDate <= other.EndDate,
                cancellationToken);

        if (taken)
        {
            throw new BusinessException(
                "These dates already carry an entry. Remove that one before adding this.");
        }
    }

    private IQueryable<AccommodationAvailability> ForListing(int accommodationId) =>
        db.AccommodationAvailability.Where(range => range.AccommodationId == accommodationId);

    private IQueryable<AccommodationAvailability> ForRange(int accommodationId, int availabilityId) =>
        ForListing(accommodationId).Where(range => range.Id == availabilityId);

    private async Task<AccommodationAvailabilityResponse> ReadAsync(
        int accommodationId,
        int availabilityId,
        CancellationToken cancellationToken) =>
        await ForRange(accommodationId, availabilityId)
            .AsNoTracking()
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(availabilityId);

    private static NotFoundException Missing(int availabilityId) =>
        new($"No availability range has the id {availabilityId}.");
}
