using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Users;

internal sealed class UserService(GostioDbContext db, ICurrentUser currentUser)
    : CrudService<User, UserResponse, UserSearchRequest, UserCreateRequest, UserUpdateRequest>(
        db,
        "user"),
      IUserService
{
    protected override string StillReferencedMessage =>
        "This account owns records that have to be kept. Deactivate it instead of deleting it.";

    protected override Expression<Func<User, UserResponse>> Projection =>
        user => new UserResponse
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Username = user.Username,
            Email = user.Email,
            PhoneNumber = user.PhoneNumber,
            IsActive = user.IsActive,
            Roles = user.UserRoles.Select(assignment => assignment.Role.Name).ToList(),
            CreatedAt = user.CreatedAt,
        };

    protected override IOrderedQueryable<User> Order(IQueryable<User> query) =>
        query.OrderBy(user => user.LastName).ThenBy(user => user.FirstName).ThenBy(user => user.Id);

    public override Task<UserResponse> GetAsync(int id, CancellationToken cancellationToken)
    {
        RequireSelfOrAdministrator(id);

        return base.GetAsync(id, cancellationToken);
    }

    public override Task<UserResponse> UpdateAsync(
        int id,
        UserUpdateRequest request,
        CancellationToken cancellationToken)
    {
        RequireSelfOrAdministrator(id);

        return base.UpdateAsync(id, request, cancellationToken);
    }

    public override Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        RequireAnotherAccount(id, "delete");

        return base.DeleteAsync(id, cancellationToken);
    }

    public async Task<UserResponse> SetRolesAsync(
        int id,
        UserRolesRequest request,
        CancellationToken cancellationToken)
    {
        var wanted = await RequireRoleIdsAsync(
            request.Roles, nameof(request.Roles), cancellationToken);

        var now = DateTime.UtcNow;

        await using var transaction = await Db.Database.BeginTransactionAsync(cancellationToken);

        // Raised in the database and raised first: the statement holds the row
        // until this commits, so a second caller cannot write a version it read
        // before this one wrote, nor diff the roles this one is replacing.
        var found = await Db.Users
            .Where(user => user.Id == id)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(user => user.TokenVersion, user => user.TokenVersion + 1)
                    .SetProperty(user => user.ModifiedAt, (DateTime?)now),
                cancellationToken);

        if (found == 0)
        {
            throw Missing(id);
        }

        var held = await Db.UserRoles
            .Where(assignment => assignment.UserId == id)
            .ToListAsync(cancellationToken);

        var dropped = held.Where(assignment => !wanted.Contains(assignment.RoleId)).ToList();
        var added = wanted
            .Where(roleId => held.All(assignment => assignment.RoleId != roleId))
            .ToList();

        // Rolled back rather than committed, so saving a form that changed
        // nothing does not sign the account holder out.
        if (dropped.Count == 0 && added.Count == 0)
        {
            await transaction.RollbackAsync(cancellationToken);

            return await ReadAsync(id, cancellationToken);
        }

        Db.UserRoles.RemoveRange(dropped);
        Db.UserRoles.AddRange(added.Select(roleId => new UserRole
        {
            UserId = id,
            RoleId = roleId,
            AssignedAt = now,
        }));

        await Db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(id, cancellationToken);
    }

    public async Task<UserResponse> SetStateAsync(
        int id,
        UserStateRequest request,
        CancellationToken cancellationToken)
    {
        var isActive = request.IsActive
            ?? throw new ValidationException(
                nameof(request.IsActive), "Say whether the account is active.");

        if (!isActive)
        {
            RequireAnotherAccount(id, "deactivate");
        }

        var user = await RequireAsync(id, cancellationToken);

        // No token version is raised: the session validator reads IsActive on
        // every request, so clearing it ends the session by itself.
        if (user.IsActive != isActive)
        {
            user.IsActive = isActive;
            user.ModifiedAt = DateTime.UtcNow;

            await Db.SaveChangesAsync(cancellationToken);
        }

        return await ReadAsync(id, cancellationToken);
    }

    protected override IQueryable<User> Filter(IQueryable<User> query, UserSearchRequest search)
    {
        if (Trimmed(search.Name) is string name)
        {
            query = query.Where(user =>
                user.FirstName.Contains(name)
                || user.LastName.Contains(name)
                || (user.FirstName + " " + user.LastName).Contains(name));
        }

        if (Trimmed(search.Username) is string username)
        {
            query = query.Where(user => user.Username.Contains(username));
        }

        if (Trimmed(search.Email) is string email)
        {
            query = query.Where(user => user.Email.Contains(email));
        }

        if (Trimmed(search.Role) is string role)
        {
            query = query.Where(user =>
                user.UserRoles.Any(assignment => assignment.Role.Name == role));
        }

        if (search.IsActive is bool isActive)
        {
            query = query.Where(user => user.IsActive == isActive);
        }

        return query;
    }

    protected override async Task<User> NewAsync(
        UserCreateRequest request,
        CancellationToken cancellationToken)
    {
        var username = request.Username.Trim();
        var email = request.Email.Trim();

        await RequireUniqueAsync(
            candidate => candidate.Username == username,
            excludeId: 0,
            nameof(request.Username),
            "This username is taken.",
            cancellationToken);

        await RequireUniqueAsync(
            candidate => candidate.Email == email,
            excludeId: 0,
            nameof(request.Email),
            "An account already uses this address.",
            cancellationToken);

        var roleIds = await RequireRoleIdsAsync(
            request.Roles, nameof(request.Roles), cancellationToken);

        var now = DateTime.UtcNow;

        return new User
        {
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            Username = username,
            Email = email,
            PhoneNumber = Trimmed(request.PhoneNumber),
            PasswordHash = PasswordHasher.Hash(request.Password),
            CreatedAt = now,
            UserRoles =
                [.. roleIds.Select(roleId => new UserRole { RoleId = roleId, AssignedAt = now })],
        };
    }

    protected override async Task ApplyAsync(
        UserUpdateRequest request,
        User user,
        CancellationToken cancellationToken)
    {
        var email = request.Email.Trim();

        await RequireUniqueAsync(
            candidate => candidate.Email == email,
            user.Id,
            nameof(request.Email),
            "An account already uses this address.",
            cancellationToken);

        user.FirstName = request.FirstName.Trim();
        user.LastName = request.LastName.Trim();
        user.Email = email;
        user.PhoneNumber = Trimmed(request.PhoneNumber);
        user.ModifiedAt = DateTime.UtcNow;
    }

    private async Task<List<int>> RequireRoleIdsAsync(
        List<string> names,
        string field,
        CancellationToken cancellationToken)
    {
        var wanted = names
            .Select(name => name.Trim())
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (wanted.Count == 0)
        {
            throw new ValidationException(field, "Give the account at least one role.");
        }

        var found = await Db.Roles
            .AsNoTracking()
            .Where(role => wanted.Contains(role.Name))
            .Select(role => new { role.Id, role.Name })
            .ToListAsync(cancellationToken);

        var unknown = wanted
            .Except(found.Select(role => role.Name), StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (unknown.Count > 0)
        {
            throw new ValidationException(field, $"No role goes by {string.Join(", ", unknown)}.");
        }

        return [.. found.Select(role => role.Id)];
    }

    private void RequireSelfOrAdministrator(int userId)
    {
        if (currentUser.RequireUserId() == userId
            || currentUser.IsInRole(RoleNames.Administrator))
        {
            return;
        }

        throw new ForbiddenException("This account may only work on its own profile.");
    }

    private void RequireAnotherAccount(int userId, string action)
    {
        if (currentUser.UserId == userId)
        {
            throw new BusinessException(
                $"An account cannot {action} itself. Ask another administrator.");
        }
    }
}
