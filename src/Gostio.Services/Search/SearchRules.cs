namespace Gostio.Services.Search;

public static class SearchRules
{
    // A search box fires a request for every keystroke, so inside this window a
    // term that only grew or lost characters is the search before it still
    // being typed rather than a search of its own.
    public static readonly TimeSpan SameSearchWindow = TimeSpan.FromMinutes(10);

    public static bool NamesSomething(SearchSignal signal) =>
        !string.IsNullOrWhiteSpace(signal.Term)
        || signal.CityId is not null
        || signal.GuestCount is not null
        || signal.MinPrice is not null
        || signal.MaxPrice is not null;

    public static bool Continues(SearchSignal signal, SearchSignal previous) =>
        signal.Target == previous.Target
        && signal.CityId == previous.CityId
        && signal.GuestCount == previous.GuestCount
        && signal.MinPrice == previous.MinPrice
        && signal.MaxPrice == previous.MaxPrice
        && OneTermStartsTheOther(signal.Term, previous.Term);

    private static bool OneTermStartsTheOther(string? term, string? previous)
    {
        var typed = term ?? string.Empty;
        var earlier = previous ?? string.Empty;

        return typed.StartsWith(earlier, StringComparison.OrdinalIgnoreCase)
            || earlier.StartsWith(typed, StringComparison.OrdinalIgnoreCase);
    }
}
