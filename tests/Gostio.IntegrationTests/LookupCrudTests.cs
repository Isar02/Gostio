using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Database.Entities;
using Gostio.Services.Lookups;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// Against SQL Server rather than in memory, because half of what is under test
// is the translation: the shared base reads Id and Name through the interfaces
// the entities implement, and a member access that does not translate fails at
// runtime with nothing in the build to show it.
[Collection(DatabaseCollection.Name)]
public class LookupCrudTests(DatabaseFixture fixture)
{
    [Fact]
    public async Task ACreatedRowIsReadBackByItsOwnId()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        var created = await amenities.CreateAsync(Named("Sauna"), CancellationToken.None);

        Assert.True(created.Id > 0);
        Assert.Equal("Sauna", created.Name);

        var read = await amenities.GetAsync(created.Id, CancellationToken.None);

        Assert.Equal(created.Id, read.Id);
        Assert.Equal("Sauna", read.Name);
    }

    [Fact]
    public async Task ANameIsStoredWithoutTheSpacesAroundIt()
    {
        await using var services = fixture.BuildServices();

        var created = await services
            .GetRequiredService<IAccommodationTypeService>()
            .CreateAsync(Named("  Treehouse  "), CancellationToken.None);

        Assert.Equal("Treehouse", created.Name);
    }

    [Fact]
    public async Task AnIdThatMatchesNothingIsNotFound()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        await Assert.ThrowsAsync<NotFoundException>(
            () => amenities.GetAsync(int.MaxValue, CancellationToken.None));
    }

    [Fact]
    public async Task ASecondRowCannotTakeANameThatIsAlreadyUsed()
    {
        await using var services = fixture.BuildServices();

        var categories = services.GetRequiredService<IExperienceCategoryService>();

        await categories.CreateAsync(Named("Sailing"), CancellationToken.None);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => categories.CreateAsync(Named("Sailing"), CancellationToken.None));

        Assert.Contains(nameof(LookupUpsertRequest.Name), refused.Errors.Keys);
    }

    // The row being written is excluded from the check by its own id, or saving
    // a form that changed something else would refuse the name it arrived with.
    [Fact]
    public async Task ARowKeepsItsOwnNameWhenItIsSavedAgain()
    {
        await using var services = fixture.BuildServices();

        var categories = services.GetRequiredService<IAccommodationCategoryService>();

        var created = await categories.CreateAsync(Named("Lakeside"), CancellationToken.None);
        var saved = await categories.UpdateAsync(
            created.Id, Named("Lakeside"), CancellationToken.None);

        Assert.Equal("Lakeside", saved.Name);
    }

    [Fact]
    public async Task ARenameIsRefusedWhenAnotherRowAlreadyHasTheName()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        await amenities.CreateAsync(Named("Fireplace"), CancellationToken.None);

        var second = await amenities.CreateAsync(Named("Hot tub"), CancellationToken.None);

        await Assert.ThrowsAsync<ValidationException>(
            () => amenities.UpdateAsync(second.Id, Named("Fireplace"), CancellationToken.None));
    }

    [Fact]
    public async Task ASearchMatchesPartOfTheNameAndPagesInNameOrder()
    {
        await using var services = fixture.BuildServices();

        var types = services.GetRequiredService<IAccommodationTypeService>();

        foreach (var name in new[] { "Yurt tent", "Yurt cabin", "Yurt lodge", "Barn" })
        {
            await types.CreateAsync(Named(name), CancellationToken.None);
        }

        var page = await types.SearchAsync(
            new LookupSearchRequest { Name = "Yurt", Page = 2, PageSize = 2 },
            CancellationToken.None);

        Assert.Equal(3, page.TotalCount);
        Assert.Equal(2, page.TotalPages);
        Assert.Equal(["Yurt tent"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task APageBeyondTheLastRowComesBackEmpty()
    {
        await using var services = fixture.BuildServices();

        var page = await services
            .GetRequiredService<IAmenityService>()
            .SearchAsync(
                new LookupSearchRequest { Name = "no amenity is called this", Page = 9 },
                CancellationToken.None);

        Assert.Empty(page.Items);
        Assert.Equal(0, page.TotalCount);
    }

    [Fact]
    public async Task ADeletedRowIsGone()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        var created = await amenities.CreateAsync(Named("Ski storage"), CancellationToken.None);

        await amenities.DeleteAsync(created.Id, CancellationToken.None);

        await Assert.ThrowsAsync<NotFoundException>(
            () => amenities.GetAsync(created.Id, CancellationToken.None));
    }

    // The restricting foreign key answers with a provider error, which the
    // shared error shape would show as an unexplained five hundred.
    [Fact]
    public async Task ARowSomethingElsePointsAtIsRefusedRatherThanFailing()
    {
        await using var services = fixture.BuildServices();

        var roles = services.GetRequiredService<IRoleService>();

        var created = await roles.CreateAsync(Named("Auditor"), CancellationToken.None);
        var userId = await fixture.AddUserAsync("a-password-for-the-referenced-role");

        await using (var db = fixture.CreateContext())
        {
            db.UserRoles.Add(new UserRole
            {
                UserId = userId,
                RoleId = created.Id,
                AssignedAt = DateTime.UtcNow,
            });

            await db.SaveChangesAsync();
        }

        var refused = await Assert.ThrowsAsync<BusinessException>(
            () => roles.DeleteAsync(created.Id, CancellationToken.None));

        Assert.Contains("cannot be deleted", refused.Message);
    }

    [Fact]
    public async Task ARoleTheEndpointsNameIsNeitherRenamedNorRemoved()
    {
        await using var services = fixture.BuildServices();

        var roles = services.GetRequiredService<IRoleService>();
        var id = await fixture.EnsureRoleAsync(RoleNames.Administrator);

        await Assert.ThrowsAsync<BusinessException>(
            () => roles.UpdateAsync(id, Named("Superuser"), CancellationToken.None));

        await Assert.ThrowsAsync<BusinessException>(
            () => roles.DeleteAsync(id, CancellationToken.None));

        await using var db = fixture.CreateContext();

        Assert.True(await db.Roles.AnyAsync(
            role => role.Id == id && role.Name == RoleNames.Administrator));
    }

    private static LookupUpsertRequest Named(string name) => new() { Name = name };
}
