using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

internal static class ReservationLock
{
    // Every writer that touches a booking and its payment takes this row first
    // and the payment row second. Two writers that take the same two rows in
    // opposite orders deadlock, and there are three of them here: a guest
    // opening a charge, a guest or a host calling the booking off, and the
    // processor settling one. Under read committed snapshot nothing else queues
    // them, because each reads before it writes.
    public static Task TakeAsync(
        GostioDbContext db,
        int reservationId,
        CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlAsync(
            $"""
            SELECT TOP 1 1 FROM [Reservations] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Id] = {reservationId}
            """,
            cancellationToken);
}
