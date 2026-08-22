namespace Gostio.Model.Authorization;

// The seed writes these names and [Authorize(Roles = ...)] matches on them.
// Both sides read the constants because the attribute compares plain strings: a
// literal that drifts on one side opens the endpoint instead of failing to build.
public static class RoleNames
{
    public const string Administrator = "Administrator";

    public const string Host = "Host";

    public const string Guest = "Guest";

    public static readonly IReadOnlyList<string> All = [Administrator, Host, Guest];
}
