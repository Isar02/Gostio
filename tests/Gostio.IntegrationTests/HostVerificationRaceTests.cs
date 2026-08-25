using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class HostVerificationRaceTests(DatabaseFixture fixture)
{
    private readonly HostVerificationWorkspace workspace = new(fixture);

    // Two administrators held at the update that answers a request and let go
    // together. One of them answers it and the other is told that it was
    // already answered: with the status out of the update both succeed, which
    // is the second one writing over an answer the applicant already has.
    [Fact]
    public async Task TwoAdministratorsAnsweringAtOnceLeaveOneAnswer()
    {
        await workspace.TheHostRoleAsync();

        var applicant = await workspace.AGuestAsync();
        var first = await workspace.AnAdministratorAsync();
        var second = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        var outcomes = await workspace.AnsweredAtOnceAsync(first, second, applied.Id);

        Assert.Single(outcomes, failure => failure is null);
        Assert.IsType<BusinessException>(
            Assert.Single(outcomes, failure => failure is not null));

        var answered = await workspace.ReadAsync(applicant, RoleNames.Guest, applied.Id);

        Assert.Equal(nameof(HostVerificationStatus.Approved), answered.Status);
        Assert.Equal(1, await workspace.HostRolesOfAsync(applicant));
    }

    // An approval and a role change through the users write the same role row.
    // The role change is run in the instant before the approval takes the
    // account, so the roles the approval reads after taking it are the ones the
    // change left. With the read back in front of the lock it has happened by
    // then and cannot see them, and the insert that follows is a duplicate key,
    // which is the ordering going away.
    [Fact]
    public async Task AnApprovalGrantsTheRoleOnceWithARoleChangeLandingUnderneathIt()
    {
        await workspace.TheHostRoleAsync();

        var applicant = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        var (outcome, landed) = await workspace.ApprovedWithTheRolesReplacedUnderneathAsync(
            administrator, applied.Id, applicant);

        Assert.True(landed);
        Assert.Null(outcome);
        Assert.Equal(1, await workspace.HostRolesOfAsync(applicant));

        var answered = await workspace.ReadAsync(applicant, RoleNames.Guest, applied.Id);

        Assert.Equal(nameof(HostVerificationStatus.Approved), answered.Status);
    }
}
