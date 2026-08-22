using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class DatabaseFixtureTests(DatabaseFixture fixture)
{
    [Fact]
    public async Task TheMigratedDatabaseHandsBackTheSeededUser()
    {
        await using var db = fixture.CreateContext();

        var user = await db.Users.SingleAsync(
            candidate => candidate.Username == DatabaseFixture.SeededUsername);

        Assert.True(user.Id > 0);
        Assert.Equal(0, user.TokenVersion);
        Assert.True(user.IsActive);
    }
}
