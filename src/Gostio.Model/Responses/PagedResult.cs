namespace Gostio.Model.Responses;

public sealed class PagedResult<T>
{
    public required IReadOnlyList<T> Items { get; init; }

    // Page and PageSize are echoed back because both are clamped on the way in,
    // and a client that asked for more needs to see what it actually got.
    public required int Page { get; init; }

    public required int PageSize { get; init; }

    public required int TotalCount { get; init; }

    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
}
