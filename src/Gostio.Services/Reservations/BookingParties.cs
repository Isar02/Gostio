using System.Globalization;

namespace Gostio.Services.Reservations;

internal sealed record BookingParty(int UserId, string Name, string Email);

internal sealed record BookedListing(
    int HostId,
    string HostName,
    string HostEmail,
    string Title);

internal sealed record BookingParties(
    int ReservationId,
    BookingParty Guest,
    BookingParty Host,
    string ListingTitle,
    DateOnly? CheckInDate,
    DateOnly? CheckOutDate,
    DateTime? SlotStartTime)
{
    private const string Day = "d MMMM yyyy";

    public string When =>
        CheckInDate is DateOnly checkIn
            ? $"{Format(checkIn)} to {Format(CheckOutDate!.Value)}"
            : $"{Format(DateOnly.FromDateTime(SlotStartTime!.Value))} at "
                + SlotStartTime!.Value.ToString("HH:mm", CultureInfo.InvariantCulture)
                + " UTC";

    private static string Format(DateOnly date) =>
        date.ToString(Day, CultureInfo.InvariantCulture);
}
