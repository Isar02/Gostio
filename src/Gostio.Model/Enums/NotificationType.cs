namespace Gostio.Model.Enums;

// Everything except HostVerificationDecided is about a reservation, which is
// what the check constraint on Notifications relies on.
public enum NotificationType
{
    ReservationCreated = 1,
    ReservationStatusChanged = 2,
    PaymentSucceeded = 3,
    RefundProcessed = 4,
    HostVerificationDecided = 5
}
