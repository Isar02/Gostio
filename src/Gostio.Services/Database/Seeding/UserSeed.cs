using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Validation;
using Gostio.Services.Authentication;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database.Seeding;

internal sealed record UserSeedResult(
    IReadOnlyDictionary<string, User> ByUsername,
    IReadOnlyList<User> Hosts,
    IReadOnlyList<User> Guests)
{
    public User Administrator => ByUsername["administrator"];
}

internal static class UserSeed
{
    public static async Task<UserSeedResult> SeedAsync(
        GostioDbContext db,
        LookupSeedResult lookups,
        string password,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var hash = PasswordHasher.Hash(password);
        var created = now.AddMonths(-14);

        var users = new List<User>();
        var assignments = new List<UserRole>();

        User Add(string username, string firstName, string lastName, int? photo, params string[] roles)
        {
            var image = photo is null ? (SeedImage?)null : SeedImages.Profile(photo.Value);

            var user = new User
            {
                FirstName = firstName,
                LastName = lastName,
                Username = username,
                Email = $"{username}@example.com",
                PhoneNumber = PhoneNumbers.Normalise(
                    $"+387 6{users.Count % 10} {310 + users.Count:000} {480 + users.Count * 3:000}"),
                PasswordHash = hash,
                ProfileImage = image?.Content,
                ProfileImageContentType = image?.ContentType,
                CreatedAt = created.AddDays(users.Count * 9),
            };

            users.Add(user);
            assignments.AddRange(roles.Select(role => new UserRole
            {
                User = user,
                Role = lookups.Roles[role],
                AssignedAt = user.CreatedAt,
            }));

            return user;
        }

        // The desktop client serves administrators and hosts, so its account holds both.
        Add("desktop", "Dina", "Kovačević", 1, RoleNames.Administrator, RoleNames.Host);
        Add("mobile", "Amar", "Selimović", 2, RoleNames.Guest);
        Add("administrator", "Nedim", "Alispahić", 3, RoleNames.Administrator);
        Add("host", "Lamija", "Hadžić", 4, RoleNames.Host);
        Add("guest", "Vedad", "Terzić", 5, RoleNames.Guest);

        Add("amina.hodzic", "Amina", "Hodžić", 6, RoleNames.Host);
        Add("marko.perisic", "Marko", "Perišić", null, RoleNames.Host);
        Add("lejla.begic", "Lejla", "Begić", null, RoleNames.Host);
        Add("nikola.savic", "Nikola", "Savić", null, RoleNames.Host);

        Add("emir.kovac", "Emir", "Kovač", null, RoleNames.Guest);
        Add("sara.jukic", "Sara", "Jukić", null, RoleNames.Guest);
        Add("tarik.mujic", "Tarik", "Mujić", null, RoleNames.Guest);
        Add("ivana.matic", "Ivana", "Matić", null, RoleNames.Guest);
        Add("denis.softic", "Denis", "Softić", null, RoleNames.Guest);
        Add("maja.popovic", "Maja", "Popović", null, RoleNames.Guest);

        var suspended = Add("vedran.kos", "Vedran", "Kos", null, RoleNames.Guest);
        suspended.IsActive = false;

        db.AddRange(users);
        db.AddRange(assignments);

        await db.SaveChangesAsync(cancellationToken);

        var byUsername = users.ToDictionary(user => user.Username);
        var byRole = assignments
            .GroupBy(assignment => assignment.Role.Name)
            .ToDictionary(group => group.Key, group => group.Select(entry => entry.User).ToList());

        db.AddRange(VerificationRequests(byUsername, now));
        db.AddRange(IssuedTokens(byUsername, now));

        await db.SaveChangesAsync(cancellationToken);

        return new UserSeedResult(
            byUsername,
            byRole[RoleNames.Host],
            byRole[RoleNames.Guest]);
    }

    private static IEnumerable<HostVerificationRequest> VerificationRequests(
        IReadOnlyDictionary<string, User> users,
        DateTime now)
    {
        var administrator = users["administrator"];

        HostVerificationRequest Approved(string username, int monthsAgo) => new()
        {
            User = users[username],
            Status = HostVerificationStatus.Approved,
            SubmittedAt = now.AddMonths(-monthsAgo),
            ReviewedByUser = administrator,
            ReviewedAt = now.AddMonths(-monthsAgo).AddDays(2),
            DecisionReason = "Identity document and property ownership both checked out.",
        };

        yield return Approved("desktop", 13);
        yield return Approved("host", 12);
        yield return Approved("amina.hodzic", 11);
        yield return Approved("marko.perisic", 10);
        yield return Approved("lejla.begic", 8);
        yield return Approved("nikola.savic", 7);

        yield return new HostVerificationRequest
        {
            User = users["denis.softic"],
            Status = HostVerificationStatus.Pending,
            SubmittedAt = now.AddDays(-6),
        };

        yield return new HostVerificationRequest
        {
            User = users["emir.kovac"],
            Status = HostVerificationStatus.Rejected,
            SubmittedAt = now.AddMonths(-3),
            ReviewedByUser = administrator,
            ReviewedAt = now.AddMonths(-3).AddDays(1),
            DecisionReason = "The uploaded document was unreadable; a clearer scan is welcome.",
        };
    }

    private static IEnumerable<PasswordResetToken> IssuedTokens(
        IReadOnlyDictionary<string, User> users,
        DateTime now)
    {
        yield return Issued(users["ivana.matic"], now.AddHours(-2));

        var used = Issued(users["emir.kovac"], now.AddDays(-11));
        used.UsedAt = used.CreatedAt.AddMinutes(9);

        yield return used;

        yield return Issued(users["vedran.kos"], now.AddDays(-30));
    }

    private static PasswordResetToken Issued(User user, DateTime created) =>
        new()
        {
            User = user,
            TokenHash = ResetTokens.Hash(ResetTokens.Create()),
            CreatedAt = created,
            ExpiresAt = created + ResetTokens.Lifetime,
        };
}
