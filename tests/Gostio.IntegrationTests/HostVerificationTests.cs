using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Messaging;
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

    [Fact]
    public async Task AnApprovedApplicantIsAHostAndSignedOutOfTheTokenThatSaidOtherwise()
    {
        await workspace.TheHostRoleAsync();

        var applicant = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);
        var before = await workspace.TokenVersionOfAsync(applicant);

        var approved = await workspace.ApproveAsync(
            administrator, applied.Id, "  Both documents checked out.  ");

        Assert.Equal(nameof(HostVerificationStatus.Approved), approved.Status);
        Assert.Equal(administrator, approved.ReviewedByUserId);
        Assert.NotNull(approved.ReviewedAt);
        Assert.NotNull(approved.ReviewedByName);
        Assert.Equal("Both documents checked out.", approved.DecisionReason);
        Assert.True(await workspace.HostsAsync(applicant));
        Assert.Equal(before + 1, await workspace.TokenVersionOfAsync(applicant));
    }

    [Fact]
    public async Task ADecisionIsAnnouncedToTheApplicantAndToNobodyElse()
    {
        await workspace.TheHostRoleAsync();

        var applicant = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);
        var notices = new CapturedNotices();

        await workspace.ApproveAsync(administrator, applied.Id, "Everything matched.", notices);

        var raised = Assert.Single(notices.Of<NotificationMessage>());

        Assert.Equal(applicant, raised.UserId);
        Assert.Equal(NotificationType.HostVerificationDecided, raised.Type);
        Assert.Null(raised.ReservationId);
        Assert.Contains("Everything matched.", raised.Body);

        var mail = Assert.Single(notices.Of<EmailMessage>());

        Assert.Equal(await workspace.EmailOfAsync(applicant), mail.ToEmail);
        Assert.Equal(raised.Title, mail.Subject);
    }

    [Fact]
    public async Task ARequestThatWasAnsweredIsNotAnsweredAgain()
    {
        await workspace.TheHostRoleAsync();

        var applicant = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        await workspace.ApproveAsync(administrator, applied.Id);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.ApproveAsync(administrator, applied.Id));

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.RejectAsync(administrator, applied.Id, "Changed my mind."));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("   ")]
    public async Task ARejectionWithoutAReasonIsRefusedUnderItsOwnField(string? reason)
    {
        var applicant = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        var refusal = await Assert.ThrowsAsync<ValidationException>(
            () => workspace.RejectAsync(administrator, applied.Id, reason));

        Assert.True(refusal.Errors.ContainsKey(nameof(HostVerificationDecisionRequest.Reason)));

        var untouched = await workspace.ReadAsync(applicant, RoleNames.Guest, applied.Id);

        Assert.Equal(nameof(HostVerificationStatus.Pending), untouched.Status);
    }

    [Fact]
    public async Task ARejectedApplicantHostsNothingAndMayApplyAgain()
    {
        var applicant = await workspace.AGuestAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        var rejected = await workspace.RejectAsync(
            administrator, applied.Id, "The document was unreadable.");

        Assert.Equal(nameof(HostVerificationStatus.Rejected), rejected.Status);
        Assert.Equal("The document was unreadable.", rejected.DecisionReason);
        Assert.False(await workspace.HostsAsync(applicant));

        var again = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        Assert.NotEqual(applied.Id, again.Id);
        Assert.Equal(nameof(HostVerificationStatus.Pending), again.Status);
    }

    [Fact]
    public async Task NobodyAnswersTheirOwnRequestOrAnybodyElsesEither()
    {
        var applicant = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var applied = await workspace.ApplyAsync(applicant, RoleNames.Guest);

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.ApproveAsync(applicant, applied.Id, role: RoleNames.Guest));

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.RejectAsync(host, applied.Id, "No.", role: RoleNames.Host));

        var untouched = await workspace.ReadAsync(applicant, RoleNames.Guest, applied.Id);

        Assert.Equal(nameof(HostVerificationStatus.Pending), untouched.Status);
        Assert.False(await workspace.HostsAsync(applicant));
    }

    [Fact]
    public async Task ARequestNobodyMadeCannotBeAnswered()
    {
        var administrator = await workspace.AnAdministratorAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ApproveAsync(administrator, id: int.MaxValue));
    }
}
