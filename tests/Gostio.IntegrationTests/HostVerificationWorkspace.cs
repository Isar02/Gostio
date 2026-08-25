using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.HostVerification;
using Gostio.Services.Messaging;
using Gostio.Services.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed class HostVerificationWorkspace(DatabaseFixture fixture)
{
    private const string Password = "the-verification-password";

    public Task<int> AGuestAsync() => fixture.AddUserAsync(Password, RoleNames.Guest);

    public Task<int> AHostAsync() => fixture.AddUserAsync(Password, RoleNames.Host);

    public Task<int> AnAdministratorAsync() =>
        fixture.AddUserAsync(Password, RoleNames.Administrator);

    // A role can only be granted once it exists, and these tests stand on the
    // rows they write rather than on a seed.
    public Task<int> TheHostRoleAsync() => fixture.EnsureRoleAsync(RoleNames.Host);

    public Task<HostVerificationRequestResponse> ApplyAsync(int actor, string role) =>
        AsAsync(actor, role, service => service.ApplyAsync(default));

    public Task<HostVerificationRequestResponse> ApproveAsync(
        int actor,
        int id,
        string? reason = null,
        INotices? notices = null,
        string role = RoleNames.Administrator) =>
        AsAsync(
            actor,
            role,
            service => service.ApproveAsync(id, Decision(reason), default),
            notices);

    public Task<HostVerificationRequestResponse> RejectAsync(
        int actor,
        int id,
        string? reason,
        INotices? notices = null,
        string role = RoleNames.Administrator) =>
        AsAsync(
            actor,
            role,
            service => service.RejectAsync(id, Decision(reason), default),
            notices);

    public Task<HostVerificationRequestResponse> ReadAsync(int actor, string role, int id) =>
        AsAsync(actor, role, service => service.GetAsync(id, default));

    public Task<PagedResult<HostVerificationRequestResponse>> SearchAsync(
        int actor,
        string role,
        HostVerificationSearchRequest search) =>
        AsAsync(actor, role, service => service.SearchAsync(search, default));

    // Two administrators reaching the same request, held at the update that
    // answers it until both are there.
    public Task<IReadOnlyList<Exception?>> AnsweredAtOnceAsync(
        int first,
        int second,
        int id)
    {
        var barrier = new CommandBarrier(2, "UPDATE", "[HostVerificationRequests]");

        return BothAsync(
            ApproveUnderAsync(first, id, barrier),
            ApproveUnderAsync(second, id, barrier));
    }

    // The other road to the same role row, landing underneath an approval that
    // is already on its way: the roles are replaced in the instant before the
    // approval takes the account, which is the window the old order left open.
    public async Task<(Exception? Outcome, bool Landed)>
        ApprovedWithTheRolesReplacedUnderneathAsync(
            int administrator,
            int id,
            int applicant)
    {
        var replaced = new RaceInterceptor(
            "[TokenVersion]", () => ReplaceRolesAsync(administrator, applicant));

        var outcome = await OutcomeOfAsync(ApproveUnderAsync(administrator, id, replaced));

        return (outcome, replaced.Fired);
    }

    public async Task<bool> HostsAsync(int userId) => await HostRolesOfAsync(userId) > 0;

    public async Task<int> HostRolesOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.UserRoles.CountAsync(assignment =>
            assignment.UserId == userId && assignment.Role.Name == RoleNames.Host);
    }

    public async Task<int> TokenVersionOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.Users
            .Where(user => user.Id == userId)
            .Select(user => user.TokenVersion)
            .FirstAsync();
    }

    public async Task<string> EmailOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.Users
            .Where(user => user.Id == userId)
            .Select(user => user.Email)
            .FirstAsync();
    }

    private static HostVerificationDecisionRequest Decision(string? reason) =>
        new() { Reason = reason };

    private async Task ApproveUnderAsync(int administrator, int id, IInterceptor interceptor)
    {
        await using var services = Under(administrator, interceptor);

        await services.GetRequiredService<IHostVerificationService>()
            .ApproveAsync(id, Decision(null), default);
    }

    private async Task ReplaceRolesAsync(int administrator, int applicant)
    {
        await using var services = Under(administrator);

        await services.GetRequiredService<IUserService>().SetRolesAsync(
            applicant,
            new UserRolesRequest { Roles = [RoleNames.Guest, RoleNames.Host] },
            default);
    }

    private ServiceProvider Under(int administrator, params IInterceptor[] interceptors) =>
        fixture.BuildServices(
            ListingWorkspace.Caller(administrator, RoleNames.Administrator),
            gateway: null,
            new CapturedNotices(),
            interceptors);

    // Both are already running by the time either is awaited, and the one that
    // is refused does not end the other: what a race asks is which of the two
    // was turned away, not that neither was.
    private static async Task<IReadOnlyList<Exception?>> BothAsync(Task first, Task second) =>
        [await OutcomeOfAsync(first), await OutcomeOfAsync(second)];

    private static async Task<Exception?> OutcomeOfAsync(Task work)
    {
        try
        {
            await work;

            return null;
        }
        catch (Exception failure)
        {
            return failure;
        }
    }

    private async Task<TResult> AsAsync<TResult>(
        int actor,
        string role,
        Func<IHostVerificationService, Task<TResult>> work,
        INotices? notices = null)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, role),
            gateway: null,
            notices ?? new CapturedNotices());

        return await work(services.GetRequiredService<IHostVerificationService>());
    }
}
