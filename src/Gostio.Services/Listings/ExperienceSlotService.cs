using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class ExperienceSlotService(GostioDbContext db, ExperienceAccess access)
    : IExperienceSlotService
{
    public async Task<PagedResult<ExperienceSlotResponse>> SearchAsync(
        int experienceId,
        ExperienceSlotSearchRequest search,
        CancellationToken cancellationToken)
    {
        RequireAWindow(search);

        var query = Visible(experienceId);

        if (search.From is DateTime from)
        {
            query = query.Where(slot => slot.StartTime >= from);
        }

        if (search.To is DateTime to)
        {
            query = query.Where(slot => slot.StartTime <= to);
        }

        if (search.IsActive is bool isActive)
        {
            query = query.Where(slot => slot.IsActive == isActive);
        }

        var page = await query
            .OrderBy(slot => slot.StartTime)
            .ThenBy(slot => slot.Id)
            .ToPagedResultAsync(search, Projection(DateTime.UtcNow), cancellationToken);

        if (page.Items.Count == 0)
        {
            await access.RequireVisibleAsync(experienceId, cancellationToken);
        }

        return page;
    }

    public async Task<ExperienceSlotResponse> GetAsync(
        int experienceId,
        int slotId,
        CancellationToken cancellationToken)
    {
        var slot = await Visible(experienceId)
            .Where(candidate => candidate.Id == slotId)
            .Select(Projection(DateTime.UtcNow))
            .FirstOrDefaultAsync(cancellationToken);

        if (slot is null)
        {
            await access.RequireVisibleAsync(experienceId, cancellationToken);

            throw Missing(slotId);
        }

        return slot;
    }

    public async Task<ExperienceSlotResponse> AddAsync(
        int experienceId,
        ExperienceSlotCreateRequest request,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(experienceId, cancellationToken);

        var startTime = request.StartTime ?? throw new ValidationException(
            nameof(request.StartTime), "Choose when the slot starts.");

        var capacity = request.Capacity ?? throw new ValidationException(
            nameof(request.Capacity), "Say how many people the slot takes.");

        if (startTime <= DateTime.UtcNow)
        {
            throw new ValidationException(
                nameof(request.StartTime), "A slot starts at a time still to come.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await access.LockAsync(experienceId, cancellationToken);

        var slot = new ExperienceSlot
        {
            ExperienceId = experienceId,
            StartTime = startTime,
            DurationMinutes = await DurationOfAsync(experienceId, cancellationToken),
            Capacity = capacity,
            CreatedAt = DateTime.UtcNow,
        };

        await RequireTheTermIsFreeAsync(slot, cancellationToken);

        db.ExperienceSlots.Add(slot);

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(experienceId, slot.Id, cancellationToken);
    }

    public async Task<ExperienceSlotResponse> UpdateAsync(
        int experienceId,
        int slotId,
        ExperienceSlotUpdateRequest request,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(experienceId, cancellationToken);

        var capacity = request.Capacity ?? throw new ValidationException(
            nameof(request.Capacity), "Say how many people the slot takes.");

        var isActive = request.IsActive ?? throw new ValidationException(
            nameof(request.IsActive), "Say whether the slot is open for booking.");

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // The seats are counted and the capacity written under the same lock,
        // or a booking landing between the two reads leaves the row holding
        // fewer seats than the reservations against it.
        await access.LockAsync(experienceId, cancellationToken);

        var slot = await ForSlot(experienceId, slotId).FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(slotId);

        var taken = await TakenSeatsAsync(slotId, DateTime.UtcNow, cancellationToken);

        if (capacity < taken)
        {
            throw new BusinessException(
                $"This slot already holds {taken} of its places. Its capacity cannot go below "
                    + "what is booked.");
        }

        if (!isActive && taken > 0)
        {
            throw new BusinessException(
                "This slot has bookings. Closing it cancels them, and a cancellation is made "
                    + "through the reservation.");
        }

        slot.Capacity = capacity;
        slot.IsActive = isActive;

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(experienceId, slotId, cancellationToken);
    }

    public async Task DeleteAsync(
        int experienceId,
        int slotId,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(experienceId, cancellationToken);

        int removed;

        try
        {
            removed = await ForSlot(experienceId, slotId).ExecuteDeleteAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsStillReferenced(failure))
        {
            throw new BusinessException(
                "This slot has bookings that have to be kept. Close it instead of deleting it.");
        }

        if (removed == 0)
        {
            throw Missing(slotId);
        }
    }

    private static void RequireAWindow(ExperienceSlotSearchRequest search)
    {
        if (search.From is DateTime from && search.To is DateTime to && to < from)
        {
            throw new ValidationException(
                nameof(search.To), "A window ends at or after the moment it starts.");
        }
    }

    // The remaining places are read out of the reservations every time rather
    // than kept on the row. Active is ReservationQueries.IsActive and nothing
    // else: an expiry test forgotten here would leave abandoned holds sitting
    // on places for good.
    private Expression<Func<ExperienceSlot, ExperienceSlotResponse>> Projection(DateTime now) =>
        slot => new ExperienceSlotResponse
        {
            Id = slot.Id,
            ExperienceId = slot.ExperienceId,
            StartTime = slot.StartTime,
            EndTime = slot.StartTime.AddMinutes(slot.DurationMinutes),
            DurationMinutes = slot.DurationMinutes,
            Capacity = slot.Capacity,
            RemainingCapacity = slot.Capacity - db.Reservations
                .Where(reservation => reservation.ExperienceSlotId == slot.Id)
                .Where(ReservationQueries.IsActive(now))
                .Sum(reservation => reservation.GuestCount),
            IsActive = slot.IsActive,
        };

    private Task<int> TakenSeatsAsync(int slotId, DateTime now, CancellationToken cancellationToken) =>
        db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.ExperienceSlotId == slotId)
            .Where(ReservationQueries.IsActive(now))
            .SumAsync(reservation => reservation.GuestCount, cancellationToken);

    private async Task<int> DurationOfAsync(int experienceId, CancellationToken cancellationToken) =>
        await db.Experiences
            .AsNoTracking()
            .Where(experience => experience.Id == experienceId)
            .Select(experience => (int?)experience.DurationMinutes)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw access.Missing(experienceId);

    // The end is exclusive, so a term beginning the moment another ends does
    // not overlap it, while one starting a minute earlier does.
    private async Task RequireTheTermIsFreeAsync(
        ExperienceSlot slot,
        CancellationToken cancellationToken)
    {
        var endsAt = slot.StartTime.AddMinutes(slot.DurationMinutes);

        var taken = await ForExperience(slot.ExperienceId)
            .AsNoTracking()
            .AnyAsync(
                other => other.StartTime < endsAt
                    && slot.StartTime < other.StartTime.AddMinutes(other.DurationMinutes),
                cancellationToken);

        if (taken)
        {
            throw new BusinessException(
                "This term runs into one the experience already has. Remove that one before "
                    + "adding this.");
        }
    }

    private IQueryable<ExperienceSlot> ForExperience(int experienceId) =>
        db.ExperienceSlots.Where(slot => slot.ExperienceId == experienceId);

    private IQueryable<ExperienceSlot> Visible(int experienceId) =>
        ForExperience(experienceId)
            .AsNoTracking()
            .Where(slot => access.VisibleListings()
                .Any(experience => experience.Id == slot.ExperienceId));

    private IQueryable<ExperienceSlot> ForSlot(int experienceId, int slotId) =>
        ForExperience(experienceId).Where(slot => slot.Id == slotId);

    private async Task<ExperienceSlotResponse> ReadAsync(
        int experienceId,
        int slotId,
        CancellationToken cancellationToken) =>
        await ForSlot(experienceId, slotId)
            .AsNoTracking()
            .Select(Projection(DateTime.UtcNow))
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(slotId);

    private static NotFoundException Missing(int slotId) => new($"No slot has the id {slotId}.");
}
