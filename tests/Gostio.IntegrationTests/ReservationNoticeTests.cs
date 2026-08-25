using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reservations;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ReservationNoticeTests(DatabaseFixture fixture)
{
    private readonly ReservationWorkspace workspace = new(fixture);

    private static DateOnly InAMonth => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));

    [Fact]
    public async Task ANewBookingTellsTheGuestAndTheHost()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var (booked, notices) = await BookAsync(guest, listing);

        Assert.All(
            notices.Of<NotificationMessage>(),
            raised =>
            {
                Assert.Equal(NotificationType.ReservationCreated, raised.Type);
                Assert.Equal(booked.Id, raised.ReservationId);
            });

        Assert.Equal([guest, host], Told(notices));
    }

    // A screen and an inbox reach different people; both are told.
    [Fact]
    public async Task EverybodyToldOnAScreenIsToldByMailAsWell()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var (_, notices) = await BookAsync(guest, listing);

        Assert.Equal(
            [await workspace.EmailOfAsync(guest), await workspace.EmailOfAsync(host)],
            notices.Of<EmailMessage>().Select(mail => mail.ToEmail));

        Assert.Equal(
            notices.Of<NotificationMessage>().Select(raised => raised.Title),
            notices.Of<EmailMessage>().Select(mail => mail.Subject));
    }

    [Fact]
    public async Task ConfirmingABookingTellsBothSides()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, InAMonth, nights: 3);

        var (_, notices) = await workspace.WatchedAsync(
            host,
            RoleNames.Host,
            (IReservationMoveService service) => service.ConfirmAsync(booked.Id, default));

        Assert.Equal([guest, host], Told(notices));
        Assert.All(
            notices.Of<NotificationMessage>(),
            raised => Assert.Equal(NotificationType.ReservationStatusChanged, raised.Type));
    }

    [Fact]
    public async Task CancellingABookingTellsBothSides()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, InAMonth, nights: 3);

        var (_, notices) = await workspace.WatchedAsync(
            guest,
            RoleNames.Guest,
            (IReservationMoveService service) => service.CancelAsync(
                booked.Id, new ReservationCancelRequest { Reason = "Plans changed" }, default));

        Assert.Equal([guest, host], Told(notices));
    }

    // Nobody acted, so nobody would think to look.
    [Fact]
    public async Task AHoldTheSweepExpiresIsAnnouncedToBothSides()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, InAMonth, nights: 3);

        await workspace.LapseAsync(booked.Id);

        var (swept, notices) = await workspace.SweepWatchedAsync();

        Assert.True(swept.Expired >= 1);
        Assert.Contains(guest, Told(notices));
        Assert.Contains(host, Told(notices));
    }

    // Theirs to review, and nothing for the host to act on.
    [Fact]
    public async Task AFinishedStayAsksTheGuestAloneForAReview()
    {
        var (host, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, InAMonth, nights: 3);

        await workspace.ConfirmAsync(host, RoleNames.Host, booked.Id);
        await workspace.MoveTheStayAsync(
            booked.Id, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-1)));

        var (swept, notices) = await workspace.SweepWatchedAsync();

        Assert.True(swept.Completed >= 1);

        var told = notices.Of<NotificationMessage>()
            .Where(sent => sent.ReservationId == booked.Id)
            .Select(sent => sent.UserId)
            .ToArray();

        Assert.Equal([guest], told);
        Assert.DoesNotContain(host, told);
    }

    [Fact]
    public async Task ATermSaysWhenItStartsAndAStaySaysWhatNightsItCovers()
    {
        var startsAt = DateTime.UtcNow.AddDays(20).Date.AddHours(14);
        var (_, slot) = await workspace.ATermAsync(capacity: 10, startsAt: startsAt);
        var guest = await workspace.AGuestAsync();

        var (_, notices) = await workspace.WatchedAsync(
            guest,
            RoleNames.Guest,
            (IReservationService service) => service.CreateAsync(
                new ReservationCreateRequest { ExperienceSlotId = slot, GuestCount = 2 },
                default));

        var raised = notices.Of<NotificationMessage>().ToArray();

        Assert.NotEmpty(raised);
        Assert.All(
            raised, sent => Assert.Contains("14:00", sent.Body, StringComparison.Ordinal));
    }

    // Everything a notice does runs after the change it announces was committed,
    // so nothing it can fail at may reach the caller.
    [Fact]
    public async Task ABrokerNobodyCanReachDoesNotFailTheBookingItWouldAnnounce()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.ThroughAsync(
            guest,
            RoleNames.Guest,
            new BrokenNotices(),
            (IReservationService service) => service.CreateAsync(
                new ReservationCreateRequest
                {
                    AccommodationId = listing,
                    CheckInDate = InAMonth,
                    CheckOutDate = InAMonth.AddDays(3),
                    GuestCount = 2,
                },
                default));

        Assert.Equal(ReservationStatusCode.Pending, await workspace.StatusOfAsync(booked.Id));
    }

    [Fact]
    public async Task ABrokerNobodyCanReachDoesNotFailACancellation()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var booked = await workspace.BookStayAsync(guest, listing, InAMonth, nights: 3);

        await workspace.ThroughAsync(
            guest,
            RoleNames.Guest,
            new BrokenNotices(),
            (IReservationMoveService service) => service.CancelAsync(
                booked.Id, new ReservationCancelRequest { Reason = "Plans changed" }, default));

        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(booked.Id));
    }

    // One booking nobody could be told about must not end the pass over all the
    // others, which is what a sweep failing at its first notice would do.
    [Fact]
    public async Task ABrokerNobodyCanReachDoesNotEndTheSweepPass()
    {
        var (_, listing) = await workspace.AListingAsync();
        var guest = await workspace.AGuestAsync();
        var first = await workspace.BookStayAsync(guest, listing, InAMonth, nights: 3);
        var second = await workspace.BookStayAsync(
            await workspace.AGuestAsync(), listing, InAMonth.AddDays(10), nights: 2);

        await workspace.LapseAsync(first.Id);
        await workspace.LapseAsync(second.Id);

        var (swept, _) = await workspace.SweepThroughAsync(new BrokenNotices());

        Assert.True(swept.Expired >= 2);
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(first.Id));
        Assert.Equal(ReservationStatusCode.Cancelled, await workspace.StatusOfAsync(second.Id));
    }

    private Task<(ReservationResponse Answer, CapturedNotices Notices)> BookAsync(
        int guest,
        int listing) =>
        workspace.WatchedAsync(
            guest,
            RoleNames.Guest,
            (IReservationService service) => service.CreateAsync(
                new ReservationCreateRequest
                {
                    AccommodationId = listing,
                    CheckInDate = InAMonth,
                    CheckOutDate = InAMonth.AddDays(3),
                    GuestCount = 2,
                },
                default));

    private static IReadOnlyList<int> Told(CapturedNotices notices) =>
        [.. notices.Of<NotificationMessage>().Select(raised => raised.UserId)];
}
