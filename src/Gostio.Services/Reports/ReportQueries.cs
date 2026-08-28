using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Reports;

internal static class ReportQueries
{
    // A lapsed hold and a cancellation are bookings that were made and not
    // bookings that were sold, so no night and no seat is counted for them.
    public static Expression<Func<Reservation, bool>> IsSold =>
        reservation =>
            reservation.ReservationStatusId == (int)ReservationStatusCode.Confirmed
            || reservation.ReservationStatusId == (int)ReservationStatusCode.Completed;
}
