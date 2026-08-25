using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.HostVerification;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed class HostVerificationWorkspace(DatabaseFixture fixture)
{
    private const string Password = "the-verification-password";

    public Task<int> AGuestAsync() => fixture.AddUserAsync(Password, RoleNames.Guest);

    public Task<int> AHostAsync() => fixture.AddUserAsync(Password, RoleNames.Host);

    public Task<int> AnAdministratorAsync() =>
        fixture.AddUserAsync(Password, RoleNames.Administrator);

    public Task<HostVerificationRequestResponse> ApplyAsync(int actor, string role) =>
        AsAsync(actor, role, service => service.ApplyAsync(default));

    public Task<HostVerificationRequestResponse> ReadAsync(int actor, string role, int id) =>
        AsAsync(actor, role, service => service.GetAsync(id, default));

    public Task<PagedResult<HostVerificationRequestResponse>> SearchAsync(
        int actor,
        string role,
        HostVerificationSearchRequest search) =>
        AsAsync(actor, role, service => service.SearchAsync(search, default));

    private async Task<TResult> AsAsync<TResult>(
        int actor,
        string role,
        Func<IHostVerificationService, Task<TResult>> work)
    {
        await using var services = fixture.BuildServices(ListingWorkspace.Caller(actor, role));

        return await work(services.GetRequiredService<IHostVerificationService>());
    }
}
