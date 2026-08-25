using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class HostVerificationTests(DatabaseFixture fixture)
{
    private readonly HostVerificationWorkspace workspace = new(fixture);

    [Fact]
    public async Task AnAccountThatDoesNotHostAppliesAndWaits()
    {
        var applicant = await workspace.AGuestAsync();

        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        Assert.Equal(applicant, applied.UserId);
        Assert.Equal(nameof(HostVerificationStatus.Pending), applied.Status);
        Assert.NotEqual(default, applied.SubmittedAt);
        Assert.Null(applied.ReviewedByUserId);
        Assert.Null(applied.ReviewedAt);
        Assert.Null(applied.DecisionReason);
        Assert.NotEmpty(applied.Username);
    }

    [Fact]
    public async Task AnAccountThatAlreadyHostsHasNothingToAskFor()
    {
        var host = await workspace.AHostAsync();

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ApplyAsync(host, RoleNames.Host));
    }

    [Fact]
    public async Task ASecondApplicationWhileOneWaitsIsRefused()
    {
        var applicant = await workspace.AGuestAsync();

        await workspace.ApplyAsync(applicant, RoleNames.Guest);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ApplyAsync(applicant, RoleNames.Guest));
    }

    [Fact]
    public async Task ToAStrangerTheRequestDoesNotExist()
    {
        var applicant = await workspace.AGuestAsync();
        var stranger = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();

        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        Assert.Equal(
            applied.Id, (await workspace.ReadAsync(applicant, RoleNames.Guest, applied.Id)).Id);
        Assert.Equal(
            applied.Id,
            (await workspace.ReadAsync(administrator, RoleNames.Administrator, applied.Id)).Id);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stranger, RoleNames.Guest, applied.Id));
    }

    [Fact]
    public async Task NothingASearchNamesWidensWhatAnApplicantSees()
    {
        var applicant = await workspace.AGuestAsync();
        var somebodyElse = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();

        var mine = await workspace.ApplyAsync(applicant, RoleNames.Guest);
        var theirs = await workspace.ApplyAsync(somebodyElse, RoleNames.Guest);

        var asked = await workspace.SearchAsync(
            applicant, RoleNames.Guest, new HostVerificationSearchRequest { UserId = somebodyElse });

        Assert.Empty(asked.Items);

        var own = await workspace.SearchAsync(
            applicant, RoleNames.Guest, new HostVerificationSearchRequest());

        Assert.Equal(mine.Id, Assert.Single(own.Items).Id);

        var everybodys = await workspace.SearchAsync(
            administrator,
            RoleNames.Administrator,
            new HostVerificationSearchRequest
            {
                Status = HostVerificationStatus.Pending,
                PageSize = 100,
            });

        Assert.Contains(everybodys.Items, request => request.Id == mine.Id);
        Assert.Contains(everybodys.Items, request => request.Id == theirs.Id);
    }
}
