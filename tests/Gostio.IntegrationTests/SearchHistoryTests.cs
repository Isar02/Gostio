using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Gostio.Services.Search;
using Microsoft.EntityFrameworkCore;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class SearchHistoryTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-somebody-searching";

    private readonly AccommodationWorkspace accommodations = new(fixture);

    private readonly ExperienceWorkspace experiences = new(fixture);

    [Fact]
    public async Task WhatAGuestSearchedForIsWrittenDown()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var city = await fixture.EnsureCityAsync("Sarajevo");

        await SearchAsync(guest, new AccommodationSearchRequest
        {
            Title = "  old town  ",
            CityId = city,
            MinGuests = 2,
            MinPrice = 40m,
            MaxPrice = 120m,
        });

        var row = Assert.Single(await RecordedAsync(guest));

        Assert.Equal(SearchTarget.Accommodations, row.Target);
        Assert.Equal("old town", row.Term);
        Assert.Equal(city, row.CityId);
        Assert.Equal(2, row.GuestCount);
        Assert.Equal(40m, row.MinPrice);
        Assert.Equal(120m, row.MaxPrice);
    }

    [Fact]
    public async Task ASearchNobodyIsSignedInForIsWrittenNowhere()
    {
        var before = await CountAsync();

        await accommodations.AsAsync(
            new AnonymousUser(),
            (IAccommodationService listings) => listings.SearchAsync(
                new AccommodationSearchRequest { Title = "old town" }, default));

        Assert.Equal(before, await CountAsync());
    }

    [Fact]
    public async Task ASearchThatNamesNothingWorthKeepingIsWrittenNowhere()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        await SearchAsync(guest, new AccommodationSearchRequest { HostId = guest });

        Assert.Empty(await RecordedAsync(guest));
    }

    [Fact]
    public async Task APageAfterTheFirstIsTheSearchThatAlreadyRan()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "loft", Page = 2 });

        Assert.Empty(await RecordedAsync(guest));
    }

    [Fact]
    public async Task ATermBeingTypedLeavesOneRowHoldingWhatWasTyped()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "sara" });

        var first = Assert.Single(await RecordedAsync(guest));

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "saraj" });
        await SearchAsync(guest, new AccommodationSearchRequest { Title = "sarajevo" });

        var last = Assert.Single(await RecordedAsync(guest));

        Assert.Equal(first.Id, last.Id);
        Assert.Equal("sarajevo", last.Term);
        Assert.True(last.SearchedAt >= first.SearchedAt);
    }

    // The prefix is not the newest row by then, and reading only the newest
    // would leave the word being typed as a second row of the same search.
    [Fact]
    public async Task ASearchOfSomethingElseInBetweenDoesNotHideThePrefix()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "sara" });
        await SearchAsync(guest, new AccommodationSearchRequest { Title = "villa" });
        await SearchAsync(guest, new AccommodationSearchRequest { Title = "sarajevo" });

        Assert.Collection(
            await RecordedAsync(guest),
            row => Assert.Equal("sarajevo", row.Term),
            row => Assert.Equal("villa", row.Term));
    }

    [Fact]
    public async Task ASearchNarrowedByAnotherFilterIsARowOfItsOwn()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var city = await fixture.EnsureCityAsync("Mostar");

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "loft" });
        await SearchAsync(guest, new AccommodationSearchRequest { Title = "loft", CityId = city });

        var rows = await RecordedAsync(guest);

        Assert.Equal(2, rows.Count);
        Assert.Collection(
            rows,
            row => Assert.Null(row.CityId),
            row => Assert.Equal(city, row.CityId));
    }

    [Fact]
    public async Task ASearchOfTheOtherCatalogueIsARowOfItsOwn()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "walking" });

        await experiences.AsAsync(
            ListingWorkspace.Caller(guest, RoleNames.Guest),
            (IExperienceService listings) => listings.SearchAsync(
                new ExperienceSearchRequest { Title = "walking", Places = 3 }, default));

        var rows = await RecordedAsync(guest);

        Assert.Equal(2, rows.Count);
        Assert.Collection(
            rows,
            row => Assert.Equal(SearchTarget.Accommodations, row.Target),
            row =>
            {
                Assert.Equal(SearchTarget.Experiences, row.Target);
                Assert.Equal(3, row.GuestCount);
            });
    }

    // A request slow enough to outlive the window it started in is the case
    // this guards, and the row another search left while it ran is what would
    // swallow it. The row is written straight to the table rather than by
    // slowing a search down, because the bound under test is the query's.
    [Fact]
    public async Task ARowFurtherAheadThanTheWindowSwallowsNoSearch()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var pastTheWindow = SearchRules.SameSearchWindow + TimeSpan.FromMinutes(1);

        await WriteAsync(guest, "sarajevo", DateTime.UtcNow + pastTheWindow);

        await SearchAsync(guest, new AccommodationSearchRequest { Title = "sara" });

        Assert.Equal(2, (await RecordedAsync(guest)).Count);
    }

    // The city is a foreign key, so an id no row carries is a write that cannot
    // land. What the caller asked for still has to be answered.
    [Fact]
    public async Task ASearchNamingACityThatDoesNotExistIsStillAnswered()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var page = await SearchAsync(
            guest, new AccommodationSearchRequest { Title = "loft", CityId = int.MaxValue });

        Assert.Empty(page.Items);
        Assert.Empty(await RecordedAsync(guest));
    }

    private Task<PagedResult<AccommodationResponse>> SearchAsync(
        int guest,
        AccommodationSearchRequest search) =>
        accommodations.AsAsync(
            ListingWorkspace.Caller(guest, RoleNames.Guest),
            (IAccommodationService listings) => listings.SearchAsync(search, default));

    private async Task WriteAsync(int userId, string term, DateTime searchedAt)
    {
        await using var db = fixture.CreateContext();

        db.SearchHistory.Add(new SearchHistory
        {
            UserId = userId,
            Target = SearchTarget.Accommodations,
            Term = term,
            SearchedAt = searchedAt,
        });

        await db.SaveChangesAsync();
    }

    private async Task<List<SearchHistory>> RecordedAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.SearchHistory
            .AsNoTracking()
            .Where(row => row.UserId == userId)
            .OrderBy(row => row.Id)
            .ToListAsync();
    }

    private async Task<int> CountAsync()
    {
        await using var db = fixture.CreateContext();

        return await db.SearchHistory.CountAsync();
    }
}
