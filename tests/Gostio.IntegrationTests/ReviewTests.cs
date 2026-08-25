using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReviewTests(DatabaseFixture fixture)
{
    private static DateOnly Soon => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(20));

    private readonly ReviewWorkspace workspace = new(fixture);

    private readonly AccommodationWorkspace listings = new(fixture);

    [Fact]
    public async Task TheGuestOfAFinishedStayWritesOne()
    {
        var stay = await workspace.ACompletedStayAsync();

        var written = await workspace.WriteAsync(
            stay.Guest, RoleNames.Guest, stay.Booking, rating: 5, comment: "  A fine place.  ");

        Assert.Equal(stay.Booking, written.ReservationId);
        Assert.Equal(stay.Guest, written.GuestId);
        Assert.Equal(stay.Accommodation, written.AccommodationId);
        Assert.Null(written.ExperienceId);
        Assert.Equal(5, written.Rating);
        Assert.Equal("A fine place.", written.Comment);
        Assert.Null(written.ModifiedAt);
        Assert.NotEmpty(written.ListingTitle);
    }

    [Fact]
    public async Task AFinishedTermIsReviewedTheSameWay()
    {
        var term = await workspace.ACompletedTermAsync();

        var written = await workspace.WriteAsync(term.Guest, RoleNames.Guest, term.Booking);

        Assert.Equal(term.Experience, written.ExperienceId);
        Assert.Null(written.AccommodationId);
    }

    [Fact]
    public async Task ACommentThatSaysNothingIsStoredAsNothing()
    {
        var stay = await workspace.ACompletedStayAsync();

        var written = await workspace.WriteAsync(
            stay.Guest, RoleNames.Guest, stay.Booking, comment: "   ");

        Assert.Null(written.Comment);
    }

    [Theory]
    [InlineData(null)]
    [InlineData(0)]
    [InlineData(6)]
    public async Task ARatingOutsideTheStarsIsRefusedUnderItsOwnField(int? rating)
    {
        var stay = await workspace.ACompletedStayAsync();

        var refusal = await Assert.ThrowsAsync<ValidationException>(
            () => workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating));

        Assert.True(refusal.Errors.ContainsKey(nameof(ReviewUpsertRequest.Rating)));
    }

    [Fact]
    public async Task ABookingStillAheadOfTheGuestCannotBeReviewed()
    {
        var (host, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.WriteAsync(guest, RoleNames.Guest, booked.Id));

        await workspace.Reservations.ConfirmAsync(host, RoleNames.Host, booked.Id);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.WriteAsync(guest, RoleNames.Guest, booked.Id));
    }

    [Fact]
    public async Task ABookingThatWasCalledOffCannotBeReviewedEither()
    {
        var (_, listing) = await workspace.Reservations.AListingAsync();
        var guest = await workspace.Reservations.AGuestAsync();
        var booked = await workspace.Reservations.BookStayAsync(guest, listing, Soon, nights: 2);

        await workspace.Reservations.CancelAsync(
            guest, RoleNames.Guest, booked.Id, "Plans changed");

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.WriteAsync(guest, RoleNames.Guest, booked.Id));
    }

    [Fact]
    public async Task NeitherTheHostNorAnAdministratorSaysHowItWas()
    {
        var stay = await workspace.ACompletedStayAsync();
        var administrator = await workspace.Reservations.AnAdministratorAsync();

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.WriteAsync(stay.Host, RoleNames.Host, stay.Booking));

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.WriteAsync(
                administrator, RoleNames.Administrator, stay.Booking));
    }

    [Fact]
    public async Task ToAStrangerTheBookingDoesNotExist()
    {
        var stay = await workspace.ACompletedStayAsync();
        var stranger = await workspace.Reservations.AGuestAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.WriteAsync(stranger, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task OneStayIsReviewedOnce()
    {
        var stay = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking);

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task TwoTapsAtOnceStillLeaveOneReview()
    {
        var stay = await workspace.ACompletedStayAsync();

        var race = new RaceInterceptor(
            "INSERT",
            () => workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 3));

        await Assert.ThrowsAsync<BusinessException>(
            () => workspace.WriteAsync(
                stay.Guest, RoleNames.Guest, stay.Booking, rating: 5, interceptors: race));

        Assert.True(race.Fired);

        var left = await workspace.ReadAsync(stay.Guest, RoleNames.Guest, stay.Booking);

        Assert.Equal(3, left.Rating);

        var all = await workspace.SearchAsync(
            stay.Guest,
            RoleNames.Guest,
            new ReviewSearchRequest { AccommodationId = stay.Accommodation });

        Assert.Equal(1, all.TotalCount);
    }

    [Fact]
    public async Task AReviewIsReadBackThroughTheBookingItHangsOff()
    {
        var stay = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, comment: "Warm.");

        var read = await workspace.ReadAsync(stay.Host, RoleNames.Host, stay.Booking);

        Assert.Equal("Warm.", read.Comment);
    }

    [Fact]
    public async Task ABookingNobodyReviewedHasNoReview()
    {
        var stay = await workspace.ACompletedStayAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stay.Guest, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task TheGuestChangesTheirMindAndTheRowSaysWhen()
    {
        var stay = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 5);

        var edited = await workspace.UpdateAsync(
            stay.Guest, RoleNames.Guest, stay.Booking, rating: 2, comment: "The heating failed.");

        Assert.Equal(2, edited.Rating);
        Assert.Equal("The heating failed.", edited.Comment);
        Assert.NotNull(edited.ModifiedAt);
    }

    [Fact]
    public async Task NobodyButTheGuestChangesIt()
    {
        var stay = await workspace.ACompletedStayAsync();
        var administrator = await workspace.Reservations.AnAdministratorAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking);

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.UpdateAsync(stay.Host, RoleNames.Host, stay.Booking));

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.UpdateAsync(administrator, RoleNames.Administrator, stay.Booking));
    }

    [Fact]
    public async Task ThereIsNothingToChangeUntilOneIsWritten()
    {
        var stay = await workspace.ACompletedStayAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.UpdateAsync(stay.Guest, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task TheGuestTakesTheirOwnBack()
    {
        var stay = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking);
        await workspace.DeleteAsync(stay.Guest, RoleNames.Guest, stay.Booking);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stay.Guest, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task AnAdministratorTakesOneDownAndAHostNever()
    {
        var stay = await workspace.ACompletedStayAsync();
        var administrator = await workspace.Reservations.AnAdministratorAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 1);

        await Assert.ThrowsAsync<ForbiddenException>(
            () => workspace.DeleteAsync(stay.Host, RoleNames.Host, stay.Booking));

        await workspace.DeleteAsync(administrator, RoleNames.Administrator, stay.Booking);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(stay.Guest, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task TakingBackOneThatIsNotThereIsNotFound()
    {
        var stay = await workspace.ACompletedStayAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.DeleteAsync(stay.Guest, RoleNames.Guest, stay.Booking));
    }

    [Fact]
    public async Task TheListNarrowsByWhatWasBookedAndByWhoBookedIt()
    {
        var stay = await workspace.ACompletedStayAsync();
        var term = await workspace.ACompletedTermAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 5);
        await workspace.WriteAsync(term.Guest, RoleNames.Guest, term.Booking, rating: 3);

        var byListing = await workspace.SearchAsync(
            stay.Guest,
            RoleNames.Guest,
            new ReviewSearchRequest { AccommodationId = stay.Accommodation });

        Assert.Equal(stay.Booking, Assert.Single(byListing.Items).ReservationId);

        var byExperience = await workspace.SearchAsync(
            stay.Guest,
            RoleNames.Guest,
            new ReviewSearchRequest { ExperienceId = term.Experience });

        Assert.Equal(term.Booking, Assert.Single(byExperience.Items).ReservationId);

        var byGuest = await workspace.SearchAsync(
            stay.Host, RoleNames.Host, new ReviewSearchRequest { GuestId = term.Guest });

        Assert.Equal(term.Booking, Assert.Single(byGuest.Items).ReservationId);
    }

    [Fact]
    public async Task TheListNarrowsByHostAcrossBothKindsOfListing()
    {
        var stay = await workspace.ACompletedStayAsync();
        var term = await workspace.ACompletedTermAsync(stay.Host);

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 5);
        await workspace.WriteAsync(term.Guest, RoleNames.Guest, term.Booking, rating: 4);

        var byHost = await workspace.SearchAsync(
            stay.Guest, RoleNames.Guest, new ReviewSearchRequest { HostId = stay.Host });

        Assert.Equal(
            new[] { stay.Booking, term.Booking }.Order(),
            byHost.Items.Select(review => review.ReservationId).Order());
    }

    [Fact]
    public async Task TheListNarrowsByHowManyStarsWereGiven()
    {
        var poor = await workspace.ACompletedStayAsync();
        var good = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(poor.Guest, RoleNames.Guest, poor.Booking, rating: 1);
        await workspace.WriteAsync(good.Guest, RoleNames.Guest, good.Booking, rating: 5);

        var complaints = await workspace.SearchAsync(
            poor.Guest,
            RoleNames.Guest,
            new ReviewSearchRequest { HostId = poor.Host, MaxRating = 2 });

        Assert.Equal(poor.Booking, Assert.Single(complaints.Items).ReservationId);

        var praise = await workspace.SearchAsync(
            good.Guest,
            RoleNames.Guest,
            new ReviewSearchRequest { HostId = good.Host, MinRating = 4 });

        Assert.Equal(good.Booking, Assert.Single(praise.Items).ReservationId);
    }

    [Fact]
    public async Task WithdrawingTheListingLeavesItsReviewsStanding()
    {
        var stay = await workspace.ACompletedStayAsync();

        await workspace.WriteAsync(stay.Guest, RoleNames.Guest, stay.Booking, rating: 1);
        await listings.WithdrawAsync(stay.Host, stay.Accommodation);

        var found = await workspace.SearchAsync(
            stay.Guest,
            RoleNames.Guest,
            new ReviewSearchRequest { AccommodationId = stay.Accommodation });

        Assert.Equal(stay.Booking, Assert.Single(found.Items).ReservationId);
    }
}
