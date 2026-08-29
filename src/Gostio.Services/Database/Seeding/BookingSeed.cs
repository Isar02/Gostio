using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database.Seeding;

// The reservation plus everything the seed derives from it, so a status and its
// payment, refund, review and notifications cannot drift apart.
internal sealed record SeededBooking(
    Reservation Reservation,
    User Host,
    ReservationStatusCode Status,
    DateTime Ends,
    PaymentStatus? Charge,
    decimal? RefundAmount,
    int? Rating,
    string? Comment);

internal sealed record BookingSeedResult(IReadOnlyList<SeededBooking> Bookings);

internal static class BookingSeed
{
    private const int PaymentDeadlineHours = 24;

    public static async Task<BookingSeedResult> SeedAsync(
        GostioDbContext db,
        UserSeedResult users,
        ListingSeedResult listings,
        string currency,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var bookings = Bookings(users, listings, now).ToList();

        db.AddRange(bookings.Select(booking => booking.Reservation));

        await db.SaveChangesAsync(cancellationToken);

        var sequence = 0;

        foreach (var booking in bookings)
        {
            sequence++;

            db.AddRange(HistoryFor(booking, now));

            var payment = PaymentFor(booking, currency, sequence);

            if (payment is not null)
            {
                db.Add(payment);

                var refund = RefundFor(booking, payment, sequence);

                if (refund is not null)
                {
                    db.Add(refund);
                }
            }

            var review = ReviewFor(booking, now);

            if (review is not null)
            {
                db.Add(review);
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        return new BookingSeedResult(bookings);
    }

    private static IEnumerable<SeededBooking> Bookings(
        UserSeedResult users,
        ListingSeedResult listings,
        DateTime now)
    {
        var accommodations = listings.Accommodations;
        var experiences = listings.Experiences;

        ExperienceSlot Slot(int experience, int slot) =>
            experiences[experience].Slots.ElementAt(slot);

        SeededBooking Stay(
            string guest,
            int accommodation,
            int checkInOffset,
            int nights,
            int guestCount,
            ReservationStatusCode status,
            PaymentStatus? payment,
            decimal? refundShare = null,
            int? rating = null,
            string? comment = null)
        {
            var listing = accommodations[accommodation];
            var checkIn = now.Date.AddDays(checkInOffset);
            var checkOut = checkIn.AddDays(nights);
            var created = Created(checkIn, now);
            var total = listing.PricePerNight * nights;
            var charged = total + listing.CleaningFee;

            return new SeededBooking(
                new Reservation
                {
                    User = users.ByUsername[guest],
                    Accommodation = listing,
                    CheckInDate = DateOnly.FromDateTime(checkIn),
                    CheckOutDate = DateOnly.FromDateTime(checkOut),
                    GuestCount = guestCount,
                    ReservationStatusId = (int)status,
                    ExpiresAt = created.AddHours(PaymentDeadlineHours),
                    AccommodationTotal = total,
                    CleaningFee = listing.CleaningFee,
                    TotalPrice = charged,
                    CreatedAt = created,
                },
                listing.Host,
                status,
                checkOut.AddHours(11),
                payment,
                RefundAmount(charged, refundShare),
                rating,
                comment);
        }

        SeededBooking Term(
            string guest,
            int experience,
            int slot,
            int guestCount,
            ReservationStatusCode status,
            PaymentStatus? payment,
            decimal? refundShare = null,
            int? rating = null,
            string? comment = null)
        {
            var listing = experiences[experience];
            var term = Slot(experience, slot);
            var created = Created(term.StartTime, now);
            var price = listing.PricePerPerson;
            var charged = price * guestCount;

            return new SeededBooking(
                new Reservation
                {
                    User = users.ByUsername[guest],
                    ExperienceSlot = term,
                    GuestCount = guestCount,
                    ReservationStatusId = (int)status,
                    ExpiresAt = created.AddHours(PaymentDeadlineHours),
                    PricePerPerson = price,
                    TotalPrice = charged,
                    CreatedAt = created,
                },
                listing.Host,
                status,
                term.StartTime.AddMinutes(term.DurationMinutes),
                payment,
                RefundAmount(charged, refundShare),
                rating,
                comment);
        }

        yield return Stay(
            "guest", 0, -120, 5, 2,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 5,
            comment: "The view is exactly what the photos promise and the host left "
                + "coffee and a map on the table.");

        yield return Stay(
            "mobile", 4, -90, 7, 4,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 4,
            comment: "Two steps from the sea and quiet at night. The kitchen could use "
                + "a second pan.");

        yield return Stay(
            "emir.kovac", 1, -60, 4, 5,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 5,
            comment: "Cool inside even at noon, and the walk down to the bridge takes "
                + "five minutes.");

        yield return Stay(
            "sara.jukic", 7, 21, 5, 6,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);

        yield return Stay(
            "tarik.mujic", 5, 34, 4, 7,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);

        yield return Stay(
            "ivana.matic", 2, 12, 3, 2,
            ReservationStatusCode.Pending, PaymentStatus.Pending);

        yield return Stay(
            "denis.softic", 8, 45, 4, 3,
            ReservationStatusCode.Cancelled, PaymentStatus.Succeeded,
            refundShare: 1m);

        yield return Stay(
            "maja.popovic", 3, 18, 4, 4,
            ReservationStatusCode.Cancelled, PaymentStatus.Cancelled);

        yield return Stay(
            "guest", 9, -30, 3, 3,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 3,
            comment: "Fine for the price and close to everything, but the street is "
                + "loud before seven.");

        yield return Stay(
            "mobile", 6, 8, 2, 1,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);

        yield return Term(
            "guest", 0, 0, 2,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 5,
            comment: "Three hours that explain the city better than any museum on "
                + "its own.");

        yield return Term(
            "mobile", 2, 0, 3,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 4,
            comment: "Well run and genuinely fun. Bring shoes you do not mind soaking.");

        yield return Term(
            "sara.jukic", 4, 2, 2,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);

        yield return Term(
            "emir.kovac", 1, 2, 4,
            ReservationStatusCode.Pending, PaymentStatus.Pending);

        yield return Term(
            "ivana.matic", 5, 2, 2,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);

        yield return Term(
            "tarik.mujic", 3, 1, 2,
            ReservationStatusCode.Completed, PaymentStatus.Succeeded,
            rating: 4,
            comment: "An easy walk with a good story at every mill.");

        yield return Term(
            "maja.popovic", 6, 2, 2,
            ReservationStatusCode.Cancelled, PaymentStatus.Succeeded,
            refundShare: 0.5m);

        yield return Term(
            "guest", 0, 3, 2,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);

        yield return Term(
            "denis.softic", 3, 2, 3,
            ReservationStatusCode.Confirmed, PaymentStatus.Succeeded);
    }

    private static DateTime Created(DateTime start, DateTime now)
    {
        var created = start.AddDays(-21);

        return created < now ? created : now.AddDays(-4);
    }

    private static IEnumerable<ReservationStatusHistory> HistoryFor(SeededBooking booking, DateTime now)
    {
        var reservation = booking.Reservation;
        var guest = reservation.User;
        var opened = reservation.CreatedAt;

        yield return new ReservationStatusHistory
        {
            Reservation = reservation,
            NewStatusId = (int)ReservationStatusCode.Pending,
            ChangedByUser = guest,
            ChangedAt = opened,
            Reason = "Reservation created and held until the payment deadline.",
        };

        var paid = opened.AddHours(3);
        var reachedConfirmed =
            booking.Status is ReservationStatusCode.Confirmed or ReservationStatusCode.Completed
            || booking.Charge == PaymentStatus.Succeeded;

        if (reachedConfirmed)
        {
            yield return new ReservationStatusHistory
            {
                Reservation = reservation,
                PreviousStatusId = (int)ReservationStatusCode.Pending,
                NewStatusId = (int)ReservationStatusCode.Confirmed,
                ChangedByUser = guest,
                ChangedAt = paid,
                Reason = "Payment succeeded.",
            };
        }

        if (booking.Status == ReservationStatusCode.Completed)
        {
            // No user: the periodic job closes a stay once it is over.
            yield return new ReservationStatusHistory
            {
                Reservation = reservation,
                PreviousStatusId = (int)ReservationStatusCode.Confirmed,
                NewStatusId = (int)ReservationStatusCode.Completed,
                ChangedAt = booking.Ends,
                Reason = "The stay ended.",
            };
        }

        if (booking.Status == ReservationStatusCode.Cancelled)
        {
            var previous = reachedConfirmed
                ? ReservationStatusCode.Confirmed
                : ReservationStatusCode.Pending;

            yield return new ReservationStatusHistory
            {
                Reservation = reservation,
                PreviousStatusId = (int)previous,
                NewStatusId = (int)ReservationStatusCode.Cancelled,
                ChangedByUser = reachedConfirmed ? guest : null,
                ChangedAt = Cancelled(reservation, now),
                Reason = reachedConfirmed
                    ? "Cancelled by the guest within the notice period."
                    : "The hold expired before the payment was completed.",
            };
        }
    }

    private static DateTime Cancelled(Reservation reservation, DateTime now)
    {
        var cancelled = reservation.CreatedAt.AddDays(4);

        return cancelled < now ? cancelled : now.AddDays(-1);
    }

    private static Payment? PaymentFor(SeededBooking booking, string currency, int sequence)
    {
        if (booking.Charge is not { } status)
        {
            return null;
        }

        var reservation = booking.Reservation;
        var opened = reservation.CreatedAt.AddMinutes(20);

        return new Payment
        {
            Reservation = reservation,
            StripePaymentIntentId = $"pi_seed_{sequence:000}",
            Status = status,
            Amount = reservation.TotalPrice,
            Currency = currency,
            CreatedAt = opened,
            ProcessedAt = status == PaymentStatus.Pending
                ? null
                : opened.AddMinutes(40),
            FailureReason = status == PaymentStatus.Cancelled
                ? "The hold expired before the card was charged."
                : null,
        };
    }

    private static decimal? RefundAmount(decimal charged, decimal? refundShare) =>
        refundShare is { } share ? Math.Round(charged * share, 2) : null;

    private static Refund? RefundFor(SeededBooking booking, Payment payment, int sequence)
    {
        if (booking.RefundAmount is not { } amount)
        {
            return null;
        }

        var opened = payment.ProcessedAt!.Value.AddDays(3);

        return new Refund
        {
            Payment = payment,
            StripeRefundId = $"re_seed_{sequence:000}",
            Status = RefundStatus.Succeeded,
            Amount = amount,
            Reason = amount >= payment.Amount
                ? "Cancelled far enough ahead for the full amount to be returned."
                : "Cancelled inside the notice period, so the policy returns part of it.",
            CreatedAt = opened,
            ProcessedAt = opened.AddHours(6),
        };
    }

    private static Review? ReviewFor(SeededBooking booking, DateTime now)
    {
        if (booking.Rating is not { } rating)
        {
            return null;
        }

        var written = booking.Ends.AddDays(2);

        return new Review
        {
            Reservation = booking.Reservation,
            Rating = rating,
            Comment = booking.Comment,
            CreatedAt = written < now ? written : now,
        };
    }
}
