using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.HostVerification;

internal sealed class HostVerificationService(GostioDbContext db, ICurrentUser currentUser)
    : IHostVerificationService
{
    private static Expression<Func<HostVerificationRequest, HostVerificationRequestResponse>>
        Projection =>
        request => new HostVerificationRequestResponse
        {
            Id = request.Id,
            UserId = request.UserId,
            Username = request.User.Username,
            ApplicantName = request.User.FirstName + " " + request.User.LastName,
            Status = request.Status.ToString(),
            SubmittedAt = request.SubmittedAt,
            ReviewedByUserId = request.ReviewedByUserId,
            ReviewedByName = request.ReviewedByUser == null
                ? null
                : request.ReviewedByUser.FirstName + " " + request.ReviewedByUser.LastName,
            ReviewedAt = request.ReviewedAt,
            DecisionReason = request.DecisionReason,
        };

    public Task<PagedResult<HostVerificationRequestResponse>> SearchAsync(
        HostVerificationSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(Reachable(), search)
            .OrderByDescending(request => request.SubmittedAt)
            .ThenByDescending(request => request.Id)
            .ToPagedResultAsync(search, Projection, cancellationToken);

    public Task<HostVerificationRequestResponse> GetAsync(
        int id,
        CancellationToken cancellationToken) =>
        ReadAsync(id, cancellationToken);

    public async Task<HostVerificationRequestResponse> ApplyAsync(
        CancellationToken cancellationToken)
    {
        var applicant = currentUser.RequireUserId();

        if (currentUser.IsInRole(RoleNames.Host))
        {
            throw new BusinessException("This account already hosts on Gostio.");
        }

        var request = new HostVerificationRequest
        {
            UserId = applicant,
            Status = HostVerificationStatus.Pending,
            SubmittedAt = DateTime.UtcNow,
        };

        db.HostVerificationRequests.Add(request);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            throw new BusinessException("A request of yours is already waiting for an answer.");
        }

        return await ReadAsync(request.Id, cancellationToken);
    }

    private static IQueryable<HostVerificationRequest> Matching(
        IQueryable<HostVerificationRequest> query,
        HostVerificationSearchRequest search)
    {
        if (search.Status is HostVerificationStatus status)
        {
            query = query.Where(request => request.Status == status);
        }

        if (search.UserId is int userId)
        {
            query = query.Where(request => request.UserId == userId);
        }

        return query;
    }

    // The applicant and an administrator over everybody, composed into the
    // statement that reads the rows, so nothing a search names widens what a
    // caller sees and a request nobody else may reach answers 404 the way one
    // that was never made does.
    private IQueryable<HostVerificationRequest> Reachable()
    {
        var query = db.HostVerificationRequests.AsNoTracking();

        if (currentUser.IsInRole(RoleNames.Administrator))
        {
            return query;
        }

        var callerId = currentUser.RequireUserId();

        return query.Where(request => request.UserId == callerId);
    }

    private async Task<HostVerificationRequestResponse> ReadAsync(
        int id,
        CancellationToken cancellationToken) =>
        await Reachable()
            .Where(request => request.Id == id)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    private static NotFoundException Missing(int id) =>
        new($"No host verification request has the id {id}.");
}
