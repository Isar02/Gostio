using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class SearchHistoryRaceTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-somebody-typing";

    private readonly AccommodationWorkspace accommodations = new(fixture);

    private static readonly string[] Keystrokes =
        ["s", "sa", "sar", "sara", "saraj", "saraje"];

    // Every keystroke of one word held at the query that answers it and let go
    // together. The account lock is what leaves one row: without it they read a
    // history holding nothing and write the row none of them found. This is
    // contention and not a proof — any number of them may still happen to run
    // one after the other — and six is where that stopped being likely enough
    // to pass with no lock at all.
    [Fact]
    public async Task KeystrokesOfOneSearchArrivingAtOnceLeaveOneRow()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var barrier = new CommandBarrier(Keystrokes.Length, "[Accommodations]");

        await Task.WhenAll([.. Keystrokes.Select(term => SearchAsync(guest, term, barrier))]);

        Assert.Single(await RecordedAsync(guest));
    }

    // The older of the two finishes last: the word the guest stopped on is
    // already in the row, and a request that started before it must not put the
    // half typed one back.
    [Fact]
    public async Task AnOlderKeystrokeFinishingLastLeavesTheWordTheGuestStoppedOn()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);

        var finished = new RaceInterceptor(
            "[Accommodations]", () => SearchAsync(guest, "sarajevo"));

        await SearchAsync(guest, "sara", finished);

        Assert.True(finished.Fired);

        var row = Assert.Single(await RecordedAsync(guest));

        Assert.Equal("sarajevo", row.Term);
    }

    private Task<PagedResult<AccommodationResponse>> SearchAsync(
        int guest,
        string term,
        params IInterceptor[] interceptors) =>
        accommodations.AsAsync(
            ListingWorkspace.Caller(guest, RoleNames.Guest),
            (IAccommodationService listings) => listings.SearchAsync(
                new AccommodationSearchRequest { Title = term }, default),
            interceptors);

    private async Task<List<SearchHistory>> RecordedAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.SearchHistory
            .AsNoTracking()
            .Where(row => row.UserId == userId)
            .ToListAsync();
    }
}
