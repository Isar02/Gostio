using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Messaging;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Messaging;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.HostVerification;

internal sealed record Applicant(int UserId, string Name, string Email);

internal sealed class HostVerificationService(
    GostioDbContext db,
    ICurrentUser currentUser,
    INotices notices) : IHostVerificationService
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

    public Task<HostVerificationRequestResponse> ApproveAsync(
        int id,
        HostVerificationDecisionRequest request,
        CancellationToken cancellationToken) =>
        DecideAsync(
            id, HostVerificationStatus.Approved, Trimmed(request.Reason), cancellationToken);

    public Task<HostVerificationRequestResponse> RejectAsync(
        int id,
        HostVerificationDecisionRequest request,
        CancellationToken cancellationToken) =>
        DecideAsync(
            id,
            HostVerificationStatus.Rejected,
            Trimmed(request.Reason) ?? throw new ValidationException(
                nameof(request.Reason), "Say why the request is being turned down."),
            cancellationToken);

    private async Task<HostVerificationRequestResponse> DecideAsync(
        int id,
        HostVerificationStatus decision,
        string? reason,
        CancellationToken cancellationToken)
    {
        var administrator = currentUser.RequireUserId();

        if (!currentUser.IsInRole(RoleNames.Administrator))
        {
            throw new ForbiddenException(
                "A verification request is an administrator's to answer.");
        }

        var applicant = await ApplicantOfAsync(id, cancellationToken);
        var now = DateTime.UtcNow;

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // The update asks for a request that is still waiting rather than for
        // the row, so the administrator who loses a race matches nothing and is
        // told so, instead of writing over an answer that has already gone out.
        var decided = await db.HostVerificationRequests
            .Where(request =>
                request.Id == id && request.Status == HostVerificationStatus.Pending)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(request => request.Status, decision)
                    .SetProperty(request => request.ReviewedByUserId, (int?)administrator)
                    .SetProperty(request => request.ReviewedAt, (DateTime?)now)
                    .SetProperty(request => request.DecisionReason, reason),
                cancellationToken);

        if (decided == 0)
        {
            throw new BusinessException("This request has already been answered. Read it again.");
        }

        if (decision == HostVerificationStatus.Approved)
        {
            await GrantTheHostRoleAsync(applicant.UserId, now, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);

        await TellAsync(applicant, decision, reason, now, cancellationToken);

        return await ReadAsync(id, cancellationToken);
    }

    private async Task GrantTheHostRoleAsync(
        int userId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var hostRoleId = await db.Roles
            .Where(role => role.Name == RoleNames.Host)
            .Select(role => (int?)role.Id)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new BusinessException($"No {RoleNames.Host} role exists to grant.");

        // The account is taken before its roles are read, which is the order
        // and the lock a role change through the users takes them in: the two
        // roads to the same role row queue behind each other rather than each
        // reading that nobody holds it and both writing it. The raise itself is
        // for the reason that one raises it, the roles riding in the token.
        await db.Users
            .Where(user => user.Id == userId)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(user => user.TokenVersion, user => user.TokenVersion + 1)
                    .SetProperty(user => user.ModifiedAt, (DateTime?)now),
                cancellationToken);

        var held = await db.UserRoles.AnyAsync(
            assignment => assignment.UserId == userId && assignment.RoleId == hostRoleId,
            cancellationToken);

        if (held)
        {
            return;
        }

        db.UserRoles.Add(new UserRole
        {
            UserId = userId,
            RoleId = hostRoleId,
            AssignedAt = now,
        });

        await db.SaveChangesAsync(cancellationToken);
    }

    private async Task TellAsync(
        Applicant applicant,
        HostVerificationStatus decision,
        string? reason,
        DateTime decidedAt,
        CancellationToken cancellationToken)
    {
        var words = HostVerificationNoticeText.Of(decision, reason);

        await notices.NotifyAsync(
            new NotificationMessage
            {
                UserId = applicant.UserId,
                Type = NotificationType.HostVerificationDecided,
                Title = words.Title,
                Body = words.Body,
                CreatedAt = decidedAt,
            },
            cancellationToken);

        await notices.SendAsync(
            new EmailMessage
            {
                ToEmail = applicant.Email,
                ToName = applicant.Name,
                Subject = words.Title,
                Body = words.Body,
            },
            cancellationToken);
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

    private async Task<Applicant> ApplicantOfAsync(int id, CancellationToken cancellationToken) =>
        await Reachable()
            .Where(request => request.Id == id)
            .Select(request => new Applicant(
                request.UserId,
                request.User.FirstName + " " + request.User.LastName,
                request.User.Email))
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    private static string? Trimmed(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static NotFoundException Missing(int id) =>
        new($"No host verification request has the id {id}.");
}
