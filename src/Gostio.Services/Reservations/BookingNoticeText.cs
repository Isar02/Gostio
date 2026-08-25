using Gostio.Model.Enums;

namespace Gostio.Services.Reservations;

internal sealed record Words(string Title, string Body);

internal sealed record Told(Words Guest, Words? Host);

internal static class BookingNoticeText
{
    public static Told Created(BookingParties booking) => new(
        Guest: new(
            "Your booking is waiting for the host",
            $"You booked {booking.ListingTitle} for {booking.When}. The host has to confirm it "
                + "before the hold on it runs out."),
        Host: new(
            "A new booking is waiting for you",
            $"{booking.Guest.Name} booked {booking.ListingTitle} for {booking.When}. Confirm it "
                + "before the hold runs out, or it is released on its own."));

    public static Told? Moved(BookingParties booking, ReservationStatusCode to) => to switch
    {
        ReservationStatusCode.Confirmed => new(
            Guest: new(
                "Your booking is confirmed",
                $"{booking.ListingTitle} is yours for {booking.When}."),
            Host: new(
                "A booking on your listing is confirmed",
                $"{booking.Guest.Name} is coming to {booking.ListingTitle} for {booking.When}.")),

        ReservationStatusCode.Cancelled => new(
            Guest: new(
                "Your booking was cancelled",
                $"{booking.ListingTitle} for {booking.When} is no longer held for you. Anything "
                    + "already paid for it goes back by the cancellation policy."),
            Host: new(
                "A booking on your listing was cancelled",
                $"{booking.Guest.Name} is no longer coming to {booking.ListingTitle} for "
                    + $"{booking.When}. The dates are open again.")),

        ReservationStatusCode.Completed => new(
            Guest: new(
                "How was it?",
                $"{booking.ListingTitle} for {booking.When} is behind you. Leaving a review is "
                    + "what tells the next guest what to expect."),
            Host: null),

        _ => null,
    };

    public static Told Paid(BookingParties booking, decimal amount, string currency) => new(
        Guest: new(
            "We have your payment",
            $"{Money(amount, currency)} was taken for {booking.ListingTitle} for "
                + $"{booking.When}."),
        Host: new(
            "A booking on your listing was paid for",
            $"{booking.Guest.Name} paid for {booking.ListingTitle} for {booking.When}."));

    // The host was told when it ended and never held the money.
    public static Told Refunded(BookingParties booking, decimal amount, string currency) => new(
        Guest: new(
            "Your refund is on its way",
            $"{Money(amount, currency)} for {booking.ListingTitle} was sent back to the card you "
                + "paid with. Your bank decides how long it takes to appear."),
        Host: null);

    private static string Money(decimal amount, string currency) =>
        $"{amount:0.00} {currency.ToUpperInvariant()}";
}
