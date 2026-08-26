using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database.Seeding;

internal static class EngagementSeed
{
    public static async Task SeedAsync(
        GostioDbContext db,
        LookupSeedResult lookups,
        UserSeedResult users,
        ListingSeedResult listings,
        BookingSeedResult bookings,
        DateTime now,
        CancellationToken cancellationToken)
    {
        db.AddRange(Conversations(users, bookings, now));
        db.AddRange(Notifications(users, bookings, now));
        db.AddRange(NewsItems(users, now));

        db.AddRange(Searches(lookups, users, now));
        db.AddRange(Favorites(users, listings, now));

        await db.SaveChangesAsync(cancellationToken);
    }

    private static IEnumerable<Conversation> Conversations(
        UserSeedResult users,
        BookingSeedResult bookings,
        DateTime now)
    {
        var administrator = users.Administrator;

        Conversation Thread(
            ConversationType type,
            Reservation? reservation,
            User first,
            User second,
            DateTime opened,
            params string[] lines)
        {
            var conversation = new Conversation
            {
                Type = type,
                OpenedByUser = first,
                Reservation = reservation,
                CreatedAt = opened,
                Participants =
                [
                    new ConversationParticipant
                    {
                        User = first,
                        JoinedAt = opened,
                        LastReadAt = opened.AddMinutes(lines.Length * 7),
                    },
                    new ConversationParticipant
                    {
                        User = second,
                        JoinedAt = opened,
                        LastReadAt = opened.AddMinutes((lines.Length - 1) * 7),
                    },
                ],
            };

            conversation.Messages =
            [
                .. lines.Select((line, position) => new Message
                {
                    SenderUser = position % 2 == 0 ? first : second,
                    Body = line,
                    SentAt = opened.AddMinutes(position * 7),
                }),
            ];

            return conversation;
        }

        Conversation AboutBooking(int index, DateTime opened, params string[] lines)
        {
            var booking = bookings.Bookings[index];

            return Thread(
                ConversationType.Direct,
                booking.Reservation,
                booking.Reservation.User,
                booking.Host,
                opened,
                lines);
        }

        yield return AboutBooking(
            0,
            bookings.Bookings[0].Reservation.CreatedAt.AddHours(5),
            "Hello, we land around nine in the evening. Is a late check-in possible?",
            "Of course. I will leave the key in the box by the door and send you the code.",
            "That works, thank you.");

        yield return AboutBooking(
            3,
            bookings.Bookings[3].Reservation.CreatedAt.AddHours(2),
            "Is there parking near the villa, or should we leave the car outside the walls?",
            "Outside the walls is the only option in the old town. I will send you the "
                + "closest garage and the walk from it.",
            "Perfect, that is what we assumed.",
            "See you in three weeks.");

        yield return AboutBooking(
            4,
            bookings.Bookings[4].Reservation.CreatedAt.AddHours(9),
            "Is the pool heated in October?",
            "It is, we keep it at 28 degrees until the season closes.");

        yield return AboutBooking(
            6,
            bookings.Bookings[6].Reservation.CreatedAt.AddDays(1),
            "Something came up at work and we have to cancel. What happens with the payment?",
            "Sorry to hear it. You are well inside the notice period, so the full amount "
                + "goes back to the same card.",
            "Thank you for being straightforward about it.");

        yield return AboutBooking(
            10,
            bookings.Bookings[10].Reservation.CreatedAt.AddHours(4),
            "How much walking is there in total?",
            "About four kilometres, all of it flat except the last stretch up to Kovači.");

        yield return AboutBooking(
            12,
            bookings.Bookings[12].Reservation.CreatedAt.AddHours(6),
            "Do you collect us at the accommodation or do we meet at the bridge?",
            "At the bridge, by the bus stop. We leave at eight sharp.");

        // An enquiry sent before anything was booked, so it carries no reservation.
        yield return Thread(
            ConversationType.Direct,
            null,
            users.ByUsername["ivana.matic"],
            users.ByUsername["lejla.begic"],
            now.AddDays(-9),
            "Is the Kotor apartment free for the first week of November?",
            "It is, and the price drops after the season ends. Send me the dates and I "
                + "will hold it for a day.");

        yield return Thread(
            ConversationType.Direct,
            null,
            users.ByUsername["tarik.mujic"],
            users.ByUsername["marko.perisic"],
            now.AddDays(-4),
            "Would the cottage take a dog?",
            "Yes, no extra charge, only keep it off the beds.");

        yield return Thread(
            ConversationType.Support,
            null,
            users.ByUsername["maja.popovic"],
            administrator,
            now.AddDays(-6),
            "My refund is showing as processed but the money is not on my card yet.",
            "It left us on Tuesday. Card refunds take up to five working days on the "
                + "bank side; write again on Friday if it has not arrived.",
            "It arrived this morning, thank you.");

        yield return Thread(
            ConversationType.Support,
            null,
            users.ByUsername["denis.softic"],
            administrator,
            now.AddDays(-3),
            "I applied to become a host last week. How long does the check usually take?",
            "Two to three working days. Yours is in the queue and nothing is missing "
                + "from it.");
    }

    private static IEnumerable<Notification> Notifications(
        UserSeedResult users,
        BookingSeedResult bookings,
        DateTime now)
    {
        foreach (var booking in bookings.Bookings)
        {
            var reservation = booking.Reservation;
            var guest = reservation.User;
            var created = reservation.CreatedAt;

            yield return new Notification
            {
                User = guest,
                Type = NotificationType.ReservationCreated,
                Reservation = reservation,
                Title = "Reservation created",
                Body = "Your reservation is held until the payment deadline.",
                ReadAt = created.AddHours(1),
                CreatedAt = created,
            };

            if (booking.Charge == PaymentStatus.Succeeded)
            {
                yield return new Notification
                {
                    User = guest,
                    Type = NotificationType.PaymentSucceeded,
                    Reservation = reservation,
                    Title = "Payment received",
                    Body = $"We charged {reservation.TotalPrice:0.00} and confirmed your "
                        + "reservation.",
                    ReadAt = created.AddHours(4),
                    CreatedAt = created.AddHours(3),
                };
            }

            if (booking.Status is ReservationStatusCode.Cancelled
                or ReservationStatusCode.Completed)
            {
                yield return new Notification
                {
                    User = guest,
                    Type = NotificationType.ReservationStatusChanged,
                    Reservation = reservation,
                    Title = booking.Status == ReservationStatusCode.Cancelled
                        ? "Reservation cancelled"
                        : "Stay completed",
                    Body = booking.Status == ReservationStatusCode.Cancelled
                        ? "The reservation was cancelled and the place is free again."
                        : "Your reservation is closed. You can leave a review now.",
                    ReadAt = null,
                    CreatedAt = booking.Ends < now ? booking.Ends : now.AddDays(-1),
                };
            }

            if (booking.RefundAmount is { } refunded)
            {
                yield return new Notification
                {
                    User = guest,
                    Type = NotificationType.RefundProcessed,
                    Reservation = reservation,
                    Title = "Refund on its way",
                    Body = $"{refunded:0.00} was returned to the card you paid with.",
                    ReadAt = null,
                    CreatedAt = now.AddDays(-2),
                };
            }
        }

        // The one type that carries no reservation, which the check constraint enforces.
        foreach (var host in new[] { "host", "amina.hodzic", "marko.perisic", "lejla.begic" })
        {
            yield return new Notification
            {
                User = users.ByUsername[host],
                Type = NotificationType.HostVerificationDecided,
                Title = "You are verified",
                Body = "Your host verification was approved. You can publish listings now.",
                ReadAt = now.AddMonths(-6),
                CreatedAt = now.AddMonths(-7),
            };
        }

        yield return new Notification
        {
            User = users.ByUsername["emir.kovac"],
            Type = NotificationType.HostVerificationDecided,
            Title = "Host verification rejected",
            Body = "The document you uploaded could not be read. Send a clearer scan and "
                + "we will look at it again.",
            ReadAt = null,
            CreatedAt = now.AddMonths(-3),
        };
    }

    private static IEnumerable<NewsItem> NewsItems(UserSeedResult users, DateTime now)
    {
        var author = users.Administrator;
        var index = 0;

        NewsItem Item(string title, string body, int daysAgo)
        {
            index++;

            return new NewsItem
            {
                CreatedByUser = author,
                Title = title,
                Body = body,
                Image = SeedImages.News(index),
                ImageContentType = SeedImages.ContentType,
                PublishedAt = now.AddDays(-daysAgo),
            };
        }

        yield return Item(
            "Experiences are now bookable alongside stays",
            "From today a host can publish a guided experience with its own terms and "
            + "capacity, and a guest books a concrete term rather than the experience in "
            + "the abstract. Everything else — payment, cancellation and refund — follows "
            + "the same path a stay already follows.",
            42);

        yield return Item(
            "A clearer cancellation policy",
            "Every reservation now shows what a cancellation would return before the "
            + "payment screen, not after it. Cancel 48 hours from booking and the full "
            + "amount comes back, unless the stay begins within the next day, in which "
            + "case the window is four hours.",
            21);

        yield return Item(
            "Host verification is faster",
            "Verification requests are decided within two working days. A rejected "
            + "request now says exactly what was wrong with it, so the second attempt "
            + "is rarely necessary.",
            9);

        yield return Item(
            "Recommendations built from what you actually look for",
            "The listings suggested on the home screen come from the searches you ran "
            + "and the places you saved, and each one says which of the two it came "
            + "from. Nothing is suggested without a reason attached to it.",
            2);
    }

    private static IEnumerable<SearchHistory> Searches(
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now)
    {
        var index = 0;

        SearchHistory Ran(
            string user,
            SearchTarget target,
            string? term,
            string? city,
            int? guests,
            decimal? minPrice,
            decimal? maxPrice)
        {
            index++;

            return new SearchHistory
            {
                User = users.ByUsername[user],
                Target = target,
                Term = term,
                City = city is null ? null : lookups.Cities[city],
                GuestCount = guests,
                MinPrice = minPrice,
                MaxPrice = maxPrice,
                SearchedAt = now.AddDays(-index).AddHours(-index % 7),
            };
        }

        yield return Ran("guest", SearchTarget.Accommodations, "old town", "Sarajevo", 2, 40m, 120m);
        yield return Ran("guest", SearchTarget.Accommodations, null, "Sarajevo", 2, null, 100m);
        yield return Ran("guest", SearchTarget.Accommodations, "loft", "Sarajevo", null, null, null);
        yield return Ran("guest", SearchTarget.Experiences, "walking tour", "Sarajevo", 2, null, 60m);
        yield return Ran("guest", SearchTarget.Experiences, null, "Mostar", 2, null, null);
        yield return Ran("guest", SearchTarget.Accommodations, "villa", "Trebinje", 6, 150m, 300m);

        yield return Ran("mobile", SearchTarget.Accommodations, "sea view", "Neum", 4, 60m, 140m);
        yield return Ran("mobile", SearchTarget.Accommodations, null, "Kotor", 3, null, 130m);
        yield return Ran("mobile", SearchTarget.Accommodations, "apartment", "Budva", 4, null, null);
        yield return Ran("mobile", SearchTarget.Experiences, "rafting", "Mostar", 3, null, 90m);
        yield return Ran("mobile", SearchTarget.Experiences, "kayak", "Kotor", 2, null, null);

        yield return Ran("emir.kovac", SearchTarget.Accommodations, "stone house", "Mostar", 5, null, 160m);
        yield return Ran("emir.kovac", SearchTarget.Accommodations, null, "Mostar", 5, 80m, 200m);
        yield return Ran("emir.kovac", SearchTarget.Experiences, "coffee", "Sarajevo", 4, null, 60m);

        yield return Ran("sara.jukic", SearchTarget.Accommodations, "dubrovnik old town", "Dubrovnik", 6, 200m, 400m);
        yield return Ran("sara.jukic", SearchTarget.Accommodations, null, "Split", 6, null, 350m);
        yield return Ran("sara.jukic", SearchTarget.Experiences, "wine", "Mostar", 2, null, 120m);

        yield return Ran("tarik.mujic", SearchTarget.Accommodations, "pool", "Trebinje", 7, 200m, 320m);
        yield return Ran("tarik.mujic", SearchTarget.Accommodations, "cottage", "Jajce", 5, null, 120m);
        yield return Ran("tarik.mujic", SearchTarget.Experiences, "waterfall", "Jajce", 2, null, null);

        yield return Ran("ivana.matic", SearchTarget.Accommodations, "studio", "Sarajevo", 2, null, 70m);
        yield return Ran("ivana.matic", SearchTarget.Accommodations, null, "Kotor", 2, 60m, 140m);
        yield return Ran("ivana.matic", SearchTarget.Experiences, "sunrise", "Kotor", 2, null, 80m);

        yield return Ran("denis.softic", SearchTarget.Accommodations, "bay", "Kotor", 3, null, 150m);
        yield return Ran("denis.softic", SearchTarget.Experiences, "hike", "Jajce", 3, null, null);

        yield return Ran("maja.popovic", SearchTarget.Accommodations, "lake", "Jajce", 4, null, 130m);
        yield return Ran("maja.popovic", SearchTarget.Experiences, "spa", "Trebinje", 2, null, 90m);
        yield return Ran("maja.popovic", SearchTarget.Experiences, null, "Trebinje", 2, null, null);
    }

    private static IEnumerable<Favorite> Favorites(
        UserSeedResult users,
        ListingSeedResult listings,
        DateTime now)
    {
        var index = 0;

        Favorite Saved(string guest, int? accommodation, int? experience)
        {
            index++;

            return new Favorite
            {
                User = users.ByUsername[guest],
                Accommodation = accommodation is null
                    ? null
                    : listings.Accommodations[accommodation.Value],
                Experience = experience is null ? null : listings.Experiences[experience.Value],
                CreatedAt = now.AddDays(-index * 4),
            };
        }

        yield return Saved("guest", 0, null);
        yield return Saved("guest", 5, null);
        yield return Saved("guest", 7, null);
        yield return Saved("guest", null, 4);
        yield return Saved("mobile", 4, null);
        yield return Saved("mobile", 8, null);
        yield return Saved("mobile", null, 2);
        yield return Saved("mobile", null, 5);
        yield return Saved("emir.kovac", 1, null);
        yield return Saved("emir.kovac", null, 1);
        yield return Saved("sara.jukic", 7, null);
        yield return Saved("sara.jukic", null, 4);
        yield return Saved("tarik.mujic", 5, null);
        yield return Saved("ivana.matic", 2, null);
        yield return Saved("ivana.matic", null, 5);
        yield return Saved("maja.popovic", 3, null);
        yield return Saved("denis.softic", 8, null);
        yield return Saved("denis.softic", null, 3);
    }
}
