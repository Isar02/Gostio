using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Authentication;
using Gostio.Services.Database.Entities;
using Gostio.Services.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class UserCrudTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-new-account";

    [Fact]
    public async Task AnAccountIsCreatedActiveWithTheRolesItWasGiven()
    {
        await fixture.EnsureRoleAsync(RoleNames.Guest);

        var created = await AsAdministratorAsync(users =>
            users.CreateAsync(New("tarik.blazevic", RoleNames.Guest), CancellationToken.None));

        Assert.True(created.Id > 0);
        Assert.True(created.IsActive);
        Assert.Equal([RoleNames.Guest], created.Roles);

        await using var db = fixture.CreateContext();

        var stored = await db.Users.SingleAsync(user => user.Id == created.Id);

        Assert.True(PasswordHasher.Verify(Password, stored.PasswordHash));
        Assert.Equal(0, stored.TokenVersion);
    }

    [Fact]
    public async Task AUsernameThatIsTakenIsRefusedUnderItsOwnField()
    {
        await fixture.EnsureRoleAsync(RoleNames.Guest);

        await AsAdministratorAsync(users =>
            users.CreateAsync(New("lana.subasic", RoleNames.Guest), CancellationToken.None));

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAdministratorAsync(
            users => users.CreateAsync(
                New("lana.subasic", RoleNames.Guest, email: "someone.else@example.com"),
                CancellationToken.None)));

        Assert.Contains(nameof(UserCreateRequest.Username), refused.Errors.Keys);
    }

    [Fact]
    public async Task AnAddressThatIsTakenIsRefusedUnderItsOwnField()
    {
        await fixture.EnsureRoleAsync(RoleNames.Guest);

        await AsAdministratorAsync(users => users.CreateAsync(
            New("mirza.delic", RoleNames.Guest, email: "shared@example.com"),
            CancellationToken.None));

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAdministratorAsync(
            users => users.CreateAsync(
                New("mirza.delic.two", RoleNames.Guest, email: "shared@example.com"),
                CancellationToken.None)));

        Assert.Contains(nameof(UserCreateRequest.Email), refused.Errors.Keys);
    }

    [Fact]
    public async Task ARoleNothingHasEverHeardOfIsRefused()
    {
        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAdministratorAsync(
            users => users.CreateAsync(
                New("nedim.karic", "Archduke"), CancellationToken.None)));

        Assert.Contains(nameof(UserCreateRequest.Roles), refused.Errors.Keys);
    }

    [Fact]
    public async Task AnAccountHolderReadsAndEditsTheirOwnProfileAndNobodyElses()
    {
        var mine = await fixture.AddUserAsync(Password);
        var theirs = await fixture.AddUserAsync(Password);

        await using var services = fixture.BuildServices(new SignedInUser(mine, RoleNames.Guest));

        var users = services.GetRequiredService<IUserService>();

        var read = await users.GetAsync(mine, CancellationToken.None);

        Assert.Equal(mine, read.Id);

        var saved = await users.UpdateAsync(
            mine,
            new UserUpdateRequest
            {
                FirstName = "Vedrana",
                LastName = "Milić",
                Email = $"vedrana.{mine}@example.com",
                PhoneNumber = "  +387 61 111 222  ",
            },
            CancellationToken.None);

        Assert.Equal("Vedrana", saved.FirstName);
        Assert.Equal("+387 61 111 222", saved.PhoneNumber);

        await Assert.ThrowsAsync<ForbiddenException>(
            () => users.GetAsync(theirs, CancellationToken.None));
    }

    [Fact]
    public async Task AnAdministratorWorksOnAnybodysRow()
    {
        var theirs = await fixture.AddUserAsync(Password);

        var read = await AsAdministratorAsync(
            users => users.GetAsync(theirs, CancellationToken.None));

        Assert.Equal(theirs, read.Id);
    }

    // The roles a token carries are written into it when it is issued, so the
    // account has to sign in again before the change means anything.
    [Fact]
    public async Task ChangingTheRolesEndsTheSessionAndSavingTheSameOnesDoesNot()
    {
        await fixture.EnsureRoleAsync(RoleNames.Guest);
        await fixture.EnsureRoleAsync(RoleNames.Host);

        var created = await AsAdministratorAsync(users =>
            users.CreateAsync(New("edin.pasic", RoleNames.Guest), CancellationToken.None));

        var promoted = await AsAdministratorAsync(users => users.SetRolesAsync(
            created.Id,
            new UserRolesRequest { Roles = [RoleNames.Guest, RoleNames.Host] },
            CancellationToken.None));

        Assert.Equal([RoleNames.Guest, RoleNames.Host], promoted.Roles.Order());
        Assert.Equal(1, await TokenVersionOfAsync(created.Id));

        await AsAdministratorAsync(users => users.SetRolesAsync(
            created.Id,
            new UserRolesRequest { Roles = [RoleNames.Host, RoleNames.Guest] },
            CancellationToken.None));

        Assert.Equal(1, await TokenVersionOfAsync(created.Id));
    }

    [Fact]
    public async Task AnAccountWithNoRoleAtAllIsRefused()
    {
        var theirs = await fixture.AddUserAsync(Password);

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAdministratorAsync(
            users => users.SetRolesAsync(
                theirs, new UserRolesRequest { Roles = [] }, CancellationToken.None)));

        Assert.Contains(nameof(UserRolesRequest.Roles), refused.Errors.Keys);
    }

    [Fact]
    public async Task DeactivatingAnAccountLeavesItInPlace()
    {
        var theirs = await fixture.AddUserAsync(Password);

        var closed = await AsAdministratorAsync(users => users.SetStateAsync(
            theirs, new UserStateRequest { IsActive = false }, CancellationToken.None));

        Assert.False(closed.IsActive);

        var reopened = await AsAdministratorAsync(users => users.SetStateAsync(
            theirs, new UserStateRequest { IsActive = true }, CancellationToken.None));

        Assert.True(reopened.IsActive);
    }

    // Both of these lock the administrator out of the application entirely.
    [Fact]
    public async Task AnAdministratorNeitherDeactivatesNorDeletesTheirOwnAccount()
    {
        var mine = await fixture.AddUserAsync(Password);

        await using var services = fixture.BuildServices(
            new SignedInUser(mine, RoleNames.Administrator));

        var users = services.GetRequiredService<IUserService>();

        await Assert.ThrowsAsync<BusinessException>(() => users.SetStateAsync(
            mine, new UserStateRequest { IsActive = false }, CancellationToken.None));

        await Assert.ThrowsAsync<BusinessException>(
            () => users.DeleteAsync(mine, CancellationToken.None));
    }

    [Fact]
    public async Task ASearchNarrowsByRoleAndByWhetherTheAccountIsOpen()
    {
        await fixture.EnsureRoleAsync("Bookkeeper");

        var open = await AsAdministratorAsync(users =>
            users.CreateAsync(New("hana.zukic", "Bookkeeper"), CancellationToken.None));

        var closed = await AsAdministratorAsync(users =>
            users.CreateAsync(New("faris.omeragic", "Bookkeeper"), CancellationToken.None));

        await AsAdministratorAsync(users => users.SetStateAsync(
            closed.Id, new UserStateRequest { IsActive = false }, CancellationToken.None));

        var page = await AsAdministratorAsync(users => users.SearchAsync(
            new UserSearchRequest { Role = "Bookkeeper", IsActive = true },
            CancellationToken.None));

        Assert.Equal([open.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task ASearchMatchesTheWholeNameAsWellAsEitherHalf()
    {
        await fixture.EnsureRoleAsync(RoleNames.Guest);

        var created = await AsAdministratorAsync(users => users.CreateAsync(
            New("zlatan.hrnjic", RoleNames.Guest, firstName: "Zlatan", lastName: "Hrnjić"),
            CancellationToken.None));

        var page = await AsAdministratorAsync(users => users.SearchAsync(
            new UserSearchRequest { Name = "Zlatan Hrnjić" }, CancellationToken.None));

        Assert.Equal([created.Id], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task AnAccountThatOwnsNothingIsDeleted()
    {
        await fixture.EnsureRoleAsync(RoleNames.Guest);

        var created = await AsAdministratorAsync(users =>
            users.CreateAsync(New("ines.brkic", RoleNames.Guest), CancellationToken.None));

        await AsAdministratorAsync(users =>
            users.DeleteAsync(created.Id, CancellationToken.None));

        await using var db = fixture.CreateContext();

        Assert.False(await db.Users.AnyAsync(user => user.Id == created.Id));
        Assert.False(await db.UserRoles.AnyAsync(row => row.UserId == created.Id));
    }

    [Fact]
    public async Task AnAccountThatOwnsRecordsIsRefusedRatherThanDeleted()
    {
        var theirs = await fixture.AddUserAsync(Password);

        await using (var db = fixture.CreateContext())
        {
            db.HostVerificationRequests.Add(new HostVerificationRequest
            {
                UserId = theirs,
                Status = HostVerificationStatus.Pending,
                SubmittedAt = DateTime.UtcNow,
            });

            await db.SaveChangesAsync();
        }

        var refused = await Assert.ThrowsAsync<BusinessException>(() => AsAdministratorAsync(
            users => users.DeleteAsync(theirs, CancellationToken.None)));

        Assert.Contains("Deactivate it", refused.Message);
    }

    private static UserCreateRequest New(
        string username,
        string role,
        string? email = null,
        string firstName = "Amina",
        string lastName = "Kovačević") =>
        new()
        {
            FirstName = firstName,
            LastName = lastName,
            Username = username,
            Email = email ?? $"{username}@example.com",
            Password = Password,
            ConfirmPassword = Password,
            Roles = [role],
        };

    private async Task<int> TokenVersionOfAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.Users.Where(user => user.Id == userId)
            .Select(user => user.TokenVersion)
            .SingleAsync();
    }

    private async Task<T> AsAdministratorAsync<T>(Func<IUserService, Task<T>> work)
    {
        await using var services = fixture.BuildServices(
            new SignedInUser(0, RoleNames.Administrator));

        return await work(services.GetRequiredService<IUserService>());
    }

    private async Task AsAdministratorAsync(Func<IUserService, Task> work)
    {
        await using var services = fixture.BuildServices(
            new SignedInUser(0, RoleNames.Administrator));

        await work(services.GetRequiredService<IUserService>());
    }
}
