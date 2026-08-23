using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Lookups;

internal sealed class RoleService(GostioDbContext db) : LookupService<Role>(db, "role"), IRoleService
{
    public override async Task<LookupResponse> UpdateAsync(
        int id,
        LookupUpsertRequest request,
        CancellationToken cancellationToken)
    {
        await RequireUnnamedByTheEndpointsAsync(id, cancellationToken);

        return await base.UpdateAsync(id, request, cancellationToken);
    }

    public override async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        await RequireUnnamedByTheEndpointsAsync(id, cancellationToken);

        await base.DeleteAsync(id, cancellationToken);
    }

    // The authorization attribute compares plain strings, so renaming one of
    // these closes every endpoint naming it rather than failing anywhere a
    // build or a request would show.
    private async Task RequireUnnamedByTheEndpointsAsync(
        int id,
        CancellationToken cancellationToken)
    {
        var name = await Set
            .AsNoTracking()
            .Where(role => role.Id == id)
            .Select(role => role.Name)
            .FirstOrDefaultAsync(cancellationToken);

        if (name is not null && RoleNames.All.Contains(name))
        {
            throw new BusinessException(
                $"The {name} role is named by the endpoints themselves and can be neither "
                    + "renamed nor removed.");
        }
    }
}
