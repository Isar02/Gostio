using Gostio.Model.Enums;
using Gostio.Model.Exceptions;

namespace Gostio.Services.Reservations;

public static class ReservationStateMachine
{
    public const ReservationStatusCode Created = ReservationStatusCode.Pending;

    private static readonly IReadOnlyDictionary<ReservationStatusCode, ReservationStatusCode[]>
        Allowed = new Dictionary<ReservationStatusCode, ReservationStatusCode[]>
        {
            [ReservationStatusCode.Pending] =
                [ReservationStatusCode.Confirmed, ReservationStatusCode.Cancelled],
            [ReservationStatusCode.Confirmed] =
                [ReservationStatusCode.Cancelled, ReservationStatusCode.Completed],
            [ReservationStatusCode.Cancelled] = [],
            [ReservationStatusCode.Completed] = [],
        };

    public static bool IsAllowed(ReservationStatusCode from, ReservationStatusCode to) =>
        Allowed.TryGetValue(from, out var targets) && targets.Contains(to);

    public static bool NeedsReason(ReservationStatusCode to) =>
        to == ReservationStatusCode.Cancelled;

    public static ReservationStatusCode RequireKnown(int statusId) =>
        Enum.IsDefined((ReservationStatusCode)statusId)
            ? (ReservationStatusCode)statusId
            : throw new BusinessException(
                $"Reservation status {statusId} is not one this application moves between.");

    public static void RequireAllowed(ReservationStatusCode from, ReservationStatusCode to)
    {
        if (!IsAllowed(from, to))
        {
            throw new BusinessException($"A {from} reservation cannot become {to}.");
        }
    }

    public static string? RequireReason(ReservationStatusCode to, string? reason)
    {
        if (NeedsReason(to) && string.IsNullOrWhiteSpace(reason))
        {
            throw new ValidationException(
                nameof(reason), "Say why the reservation is being cancelled.");
        }

        return string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();
    }
}
