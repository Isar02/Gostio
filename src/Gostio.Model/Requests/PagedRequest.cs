namespace Gostio.Model.Requests;

// Every list request derives from this. The bounds sit in the setters rather
// than in each service, so no endpoint can answer with an unbounded page.
public class PagedRequest
{
    public const int DefaultPageSize = 20;

    public const int MaxPageSize = 100;

    private int page = 1;

    private int pageSize = DefaultPageSize;

    public int Page
    {
        get => page;
        set => page = value < 1 ? 1 : value;
    }

    public int PageSize
    {
        get => pageSize;
        set => pageSize = Math.Clamp(value, 1, MaxPageSize);
    }

    // Long, because Page is bounded from below only: in int arithmetic a large
    // page overflows into a negative offset, which the database then rejects.
    public long Offset => ((long)Page - 1) * PageSize;
}
