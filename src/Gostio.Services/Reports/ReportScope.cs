using System.Linq.Expressions;

namespace Gostio.Services.Reports;

// What a report covers: the whole platform, or one host's listings. The host
// is read off the caller and never off the request, so nothing a request names
// can widen what it is answered with. The predicate is built from the host
// rather than handed in ready, so a caller cannot reach for an id that a
// platform-wide report does not have.
internal readonly record struct ReportScope(int? HostId)
{
    public static ReportScope Platform => default;

    public IQueryable<T> Narrow<T>(
        IQueryable<T> query,
        Func<int, Expression<Func<T, bool>>> toTheHost) =>
        HostId is int host ? query.Where(toTheHost(host)) : query;
}
