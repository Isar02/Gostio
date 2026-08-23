using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class ReservationStatusService(GostioDbContext db)
    : CrudService<
        ReservationStatus,
        ReservationStatusResponse,
        LookupSearchRequest,
        ReservationStatusUpsertRequest,
        ReservationStatusUpsertRequest>(db, "reservation status"),
      IReservationStatusService
{
    // A restricting foreign key blocks a delete only once a row is referenced,
    // so until the first reservation exists these four are unprotected.
    private static readonly HashSet<int> NamedByTheStateMachine =
        [.. Enum.GetValues<ReservationStatusCode>().Select(code => (int)code)];

    protected override Expression<Func<ReservationStatus, ReservationStatusResponse>> Projection =>
        status => new ReservationStatusResponse
        {
            Id = status.Id,
            Name = status.Name,
            Code = status.Code,
            Description = status.Description,
        };

    protected override IOrderedQueryable<ReservationStatus> Order(
        IQueryable<ReservationStatus> query) =>
        query.OrderBy(status => status.Id);

    protected override IQueryable<ReservationStatus> Filter(
        IQueryable<ReservationStatus> query,
        LookupSearchRequest search)
    {
        if (string.IsNullOrWhiteSpace(search.Name))
        {
            return query;
        }

        string term = search.Name.Trim();

        return query.Where(status => status.Name.Contains(term));
    }

    public override async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        if (NamedByTheStateMachine.Contains(id))
        {
            throw new BusinessException(
                $"The {(ReservationStatusCode)id} status is one the reservation state machine "
                    + "names and cannot be deleted.");
        }

        await base.DeleteAsync(id, cancellationToken);
    }

    protected override async Task<ReservationStatus> NewAsync(
        ReservationStatusUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var status = new ReservationStatus();

        await ApplyAsync(request, status, cancellationToken);

        return status;
    }

    protected override async Task ApplyAsync(
        ReservationStatusUpsertRequest request,
        ReservationStatus status,
        CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        var code = request.Code.Trim();
        var description = request.Description?.Trim();

        if (NamedByTheStateMachine.Contains(status.Id)
            && !string.Equals(code, status.Code, StringComparison.Ordinal))
        {
            throw new BusinessException(
                $"The {status.Code} status is one the reservation state machine names, so its "
                    + "code cannot change. Its name and description can.");
        }

        await RequireUniqueAsync(
            candidate => candidate.Name == name,
            status.Id,
            nameof(request.Name),
            "Another reservation status already goes by this name.",
            cancellationToken);

        await RequireUniqueAsync(
            candidate => candidate.Code == code,
            status.Id,
            nameof(request.Code),
            "Another reservation status already has this code.",
            cancellationToken);

        status.Name = name;
        status.Code = code;
        status.Description = string.IsNullOrEmpty(description) ? null : description;
    }
}
