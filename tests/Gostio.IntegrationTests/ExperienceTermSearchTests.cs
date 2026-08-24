using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ExperienceTermSearchTests(DatabaseFixture fixture)
{
    private readonly ReservationWorkspace workspace = new(fixture);

    private static DateTime Later => DateTime.UtcNow.AddDays(20);

    [Fact]
    public async Task AnExperienceWithATermInTheWindowIsFound()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var wanted = await workspace.ExperienceOfAsync(slot);

        Assert.Equal([wanted], await FoundByAsync(host, Later.AddDays(-1), Later.AddDays(1)));
    }

    [Fact]
    public async Task ATermOutsideTheWindowLeavesItsExperienceOut()
    {
        var (host, _) = await workspace.ATermAsync(capacity: 4, startsAt: Later);

        Assert.Empty(await FoundByAsync(host, Later.AddDays(1), Later.AddDays(2)));
    }

    [Fact]
    public async Task AnExperienceWithNoTermsAtAllIsNotOpen()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var withTerms = await workspace.ExperienceOfAsync(slot);

        await workspace.AnExperienceWithoutTermsAsync(host);

        Assert.Equal([withTerms], await FoundByAsync(host, null, null));
    }

    [Fact]
    public async Task ATermThatHasStartedNoLongerOpensItsExperience()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);

        await workspace.StartTheTermAsync(slot, TimeSpan.FromHours(1));

        Assert.Empty(await FoundByAsync(host, null, null));
    }

    [Fact]
    public async Task AClosedTermDoesNotOpenItsExperienceEither()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);

        await workspace.CloseTermAsync(host, slot, capacity: 4);

        Assert.Empty(await FoundByAsync(host, null, null));
    }

    [Fact]
    public async Task AFullTermTakesItsExperienceOutOfTheList()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var guest = await workspace.AGuestAsync();

        await workspace.BookTermAsync(guest, slot, guestCount: 4);

        Assert.Empty(await FoundByAsync(host, null, null));
    }

    [Fact]
    public async Task WhatIsLeftIsWhatTheSearchAsksAgainst()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var wanted = await workspace.ExperienceOfAsync(slot);
        var guest = await workspace.AGuestAsync();

        await workspace.BookTermAsync(guest, slot, guestCount: 3);

        Assert.Empty(await FoundByAsync(host, null, null, places: 2));
        Assert.Equal([wanted], await FoundByAsync(host, null, null, places: 1));
    }

    [Fact]
    public async Task ABookingThatStoppedHoldingItsPlacesGivesThemBack()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var wanted = await workspace.ExperienceOfAsync(slot);
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 4);

        Assert.Empty(await FoundByAsync(host, null, null));

        await workspace.CancelAsync(booked.Id);

        Assert.Equal([wanted], await FoundByAsync(host, null, null, places: 4));
    }

    [Fact]
    public async Task ALapsedHoldGivesThemBackTheSameWay()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var wanted = await workspace.ExperienceOfAsync(slot);
        var guest = await workspace.AGuestAsync();

        var booked = await workspace.BookTermAsync(guest, slot, guestCount: 4);

        await workspace.LapseAsync(booked.Id);

        Assert.Equal([wanted], await FoundByAsync(host, null, null, places: 4));
    }

    [Fact]
    public async Task AnExperienceIsOpenWhenAnyOneOfItsTermsIs()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var wanted = await workspace.ExperienceOfAsync(slot);
        var guest = await workspace.AGuestAsync();

        await workspace.AnotherTermAsync(host, slot, Later.AddDays(1), capacity: 4);
        await workspace.BookTermAsync(guest, slot, guestCount: 4);

        Assert.Equal([wanted], await FoundByAsync(host, null, null));
        Assert.Empty(await FoundByAsync(host, Later.AddDays(-1), Later.AddHours(12)));
        Assert.Equal([wanted], await FoundByAsync(host, Later.AddHours(12), null));
    }

    [Fact]
    public async Task AWindowThatEndsBeforeItStartsIsRefused()
    {
        var (host, _) = await workspace.ATermAsync(capacity: 4, startsAt: Later);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => FoundByAsync(host, Later.AddDays(1), Later));

        Assert.Contains(nameof(ExperienceSearchRequest.AvailableTo), refused.Errors.Keys);
    }

    [Fact]
    public async Task AnExperienceWithoutOpenTermsStillShowsInAnUnfilteredSearch()
    {
        var (host, slot) = await workspace.ATermAsync(capacity: 4, startsAt: Later);
        var experience = await workspace.ExperienceOfAsync(slot);
        var guest = await workspace.AGuestAsync();

        await workspace.BookTermAsync(guest, slot, guestCount: 4);

        var page = await workspace.SearchExperiencesAsync(
            host, RoleNames.Host, new ExperienceSearchRequest { HostId = host });

        Assert.Equal([experience], page.Items.Select(item => item.Id));
    }

    private async Task<IReadOnlyList<int>> FoundByAsync(
        int host,
        DateTime? from,
        DateTime? to,
        int? places = null)
    {
        var page = await workspace.SearchExperiencesAsync(
            host,
            RoleNames.Host,
            new ExperienceSearchRequest
            {
                HostId = host,
                AvailableFrom = from,
                AvailableTo = to,
                Places = places ?? 1,
            });

        return [.. page.Items.Select(item => item.Id)];
    }
}
