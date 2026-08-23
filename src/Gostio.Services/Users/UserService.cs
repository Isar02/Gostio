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

    // The profile image is left out of every list and every reply here: it is a
    // column of bytes, and it has an endpoint of its own to come.
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
        var user = await RequireAsync(id, cancellationToken);
        var wanted = await RequireRoleIdsAsync(
            request.Roles, nameof(request.Roles), cancellationToken);

        await Db.Entry(user).Collection(account => account.UserRoles).LoadAsync(cancellationToken);

        var held = user.UserRoles.ToList();

        // A difference rather than a clear and a refill, so a role the account
        // keeps holds the date it was first given on, and no row is deleted and
        // reinserted under the same key in one save.
        var dropped = held.Where(assignment => !wanted.Contains(assignment.RoleId)).ToList();
        var added = wanted
            .Where(roleId => held.All(assignment => assignment.RoleId != roleId))
            .ToList();

        if (dropped.Count == 0 && added.Count == 0)
        {
            return await ReadAsync(id, cancellationToken);
        }

        var now = DateTime.UtcNow;

        foreach (var assignment in dropped)
        {
            user.UserRoles.Remove(assignment);
        }

        foreach (var roleId in added)
        {
            user.UserRoles.Add(new UserRole { RoleId = roleId, AssignedAt = now });
        }

        // The roles a token carries were written into it when it was issued, so
        // the session has to end before the change means anything.
        user.TokenVersion++;
        user.ModifiedAt = now;

        await Db.SaveChangesAsync(cancellationToken);

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

        // No token version is raised here: the session validator reads IsActive
        // on every request, so clearing it ends the session by itself.
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
        if (!string.IsNullOrWhiteSpace(search.Name))
        {
            string term = search.Name.Trim();

            query = query.Where(user =>
                user.FirstName.Contains(term)
                || user.LastName.Contains(term)
                || (user.FirstName + " " + user.LastName).Contains(term));
        }

        if (!string.IsNullOrWhiteSpace(search.Username))
        {
            string term = search.Username.Trim();

            query = query.Where(user => user.Username.Contains(term));
        }

        if (!string.IsNullOrWhiteSpace(search.Email))
        {
            string term = search.Email.Trim();

            query = query.Where(user => user.Email.Contains(term));
        }

        if (!string.IsNullOrWhiteSpace(search.Role))
        {
            string role = search.Role.Trim();

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
            PhoneNumber = Given(request.PhoneNumber),
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
        user.PhoneNumber = Given(request.PhoneNumber);
        user.ModifiedAt = DateTime.UtcNow;
    }

    private static string? Given(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

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

    // The one condition no attribute can carry, and the reason ICurrentUser
    // knows about roles at all.
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
