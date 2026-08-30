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

        Conversation AboutBooking(string key, TimeSpan afterOpening, params string[] lines)
        {
            var booking = bookings.Bookings[key];

            return Thread(
                ConversationType.Direct,
                booking.Reservation,
                booking.Reservation.User,
                booking.Host,
                booking.Reservation.CreatedAt.Add(afterOpening),
                lines);
        }

        yield return AboutBooking(
            "loft-completed-stay",
            TimeSpan.FromHours(5),
            "Hello, we land around nine in the evening. Is a late check-in possible?",
            "Of course. I will leave the key in the box by the door and send you the code.",
            "That works, thank you.");

        yield return AboutBooking(
            "villa-parking-stay",
            TimeSpan.FromHours(2),
            "Is there parking at the villa, or should we leave the car down in the town?",
            "There is room for two cars inside the gate. The road up is narrow but "
                + "paved the whole way, so an ordinary car manages it.",
            "Perfect, that is what we assumed.",
            "See you in three weeks.");

        yield return AboutBooking(
            "villa-terrace-stay",
            TimeSpan.FromHours(9),
            "Does the roof terrace get much wind in the evening?",
            "The west wall shelters it in the evening, but bring a layer after sunset.");

        yield return AboutBooking(
            "konjic-refunded-stay",
            TimeSpan.FromDays(1),
            "Something came up at work and we have to cancel. What happens with the payment?",
            "Sorry to hear it. You are well inside the notice period, so the full amount "
                + "goes back to the same card.",
            "Thank you for being straightforward about it.");

        yield return AboutBooking(
            "tunnel-completed-term",
            TimeSpan.FromHours(4),
            "How much walking is there in total?",
            "About four kilometres, all of it flat except the last stretch up to Kovači.");

        yield return AboutBooking(
            "wine-confirmed-term",
            TimeSpan.FromHours(6),
            "Do you collect us at the accommodation or do we meet at the bridge?",
            "At the bridge, by the bus stop. We leave at eight sharp.");

        // An enquiry sent before anything was booked, so it carries no reservation.
        yield return Thread(
            ConversationType.Direct,
            null,
            users.ByUsername["ivana.matic"],
            users.ByUsername["lejla.begic"],
            now.AddDays(-9),
            "Is the Konjic apartment free for the first week of next month?",
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
        foreach (var booking in bookings.Bookings.Values)
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
            var image = SeedImages.News(index);

            return new NewsItem
            {
                CreatedByUser = author,
                Title = title,
                Body = body,
                Image = image.Content,
                ImageContentType = image.ContentType,
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

        yield return Ran("guest", SearchTarget.Accommodations, "old town", "Sarajevo", 2, 80m, 240m);
        yield return Ran("guest", SearchTarget.Accommodations, null, "Sarajevo", 2, null, 200m);
        yield return Ran("guest", SearchTarget.Accommodations, "loft", "Sarajevo", null, null, null);
        yield return Ran("guest", SearchTarget.Experiences, "walking tour", "Sarajevo", 2, null, 120m);
        yield return Ran("guest", SearchTarget.Experiences, null, "Mostar", 2, null, null);
        yield return Ran("guest", SearchTarget.Accommodations, "villa", "Neum", 6, 400m, 800m);

        yield return Ran("mobile", SearchTarget.Accommodations, "sea view", "Neum", 4, 120m, 280m);
        yield return Ran("mobile", SearchTarget.Accommodations, null, "Konjic", 3, null, 260m);
        yield return Ran("mobile", SearchTarget.Accommodations, "apartment", "Tuzla", 4, null, null);
        yield return Ran("mobile", SearchTarget.Experiences, "rafting", "Mostar", 3, null, 180m);
        yield return Ran("mobile", SearchTarget.Experiences, "coffee", "Sarajevo", 2, null, null);

        yield return Ran("emir.kovac", SearchTarget.Accommodations, "cottage", "Jajce", 5, null, 320m);
        yield return Ran("emir.kovac", SearchTarget.Accommodations, null, "Jajce", 5, 160m, 400m);
        yield return Ran("emir.kovac", SearchTarget.Experiences, "coffee", "Sarajevo", 4, null, 120m);

        yield return Ran("sara.jukic", SearchTarget.Accommodations, "stone villa", "Neum", 6, 400m, 800m);
        yield return Ran("sara.jukic", SearchTarget.Accommodations, null, "Neum", 6, null, 700m);
        yield return Ran("sara.jukic", SearchTarget.Experiences, "wine", "Mostar", 2, null, 240m);

        yield return Ran("tarik.mujic", SearchTarget.Accommodations, "terrace", "Neum", 7, 400m, 800m);
        yield return Ran("tarik.mujic", SearchTarget.Accommodations, "cottage", "Jajce", 5, null, 240m);
        yield return Ran("tarik.mujic", SearchTarget.Experiences, "waterfall", "Jajce", 2, null, null);

        yield return Ran("ivana.matic", SearchTarget.Accommodations, "studio", "Sarajevo", 2, null, 140m);
        yield return Ran("ivana.matic", SearchTarget.Accommodations, null, "Konjic", 2, 120m, 280m);
        yield return Ran("ivana.matic", SearchTarget.Experiences, "old town", "Sarajevo", 2, null, 160m);

        yield return Ran("denis.softic", SearchTarget.Accommodations, "river", "Konjic", 3, null, 300m);
        yield return Ran("denis.softic", SearchTarget.Experiences, "hike", "Jajce", 3, null, null);

        yield return Ran("maja.popovic", SearchTarget.Accommodations, "lake", "Jajce", 4, null, 260m);
        yield return Ran("maja.popovic", SearchTarget.Experiences, "wine", "Mostar", 2, null, 180m);
        yield return Ran("maja.popovic", SearchTarget.Experiences, null, "Mostar", 2, null, null);

        yield return Ran("guest", SearchTarget.Accommodations, "stone house", "Mostar", 5, 150m, 320m);
        yield return Ran("guest", SearchTarget.Experiences, "hammam", "Trebinje", 2, null, 140m);

        yield return Ran("mobile", SearchTarget.Accommodations, "cottage", "Travnik", 6, null, 300m);
        yield return Ran("mobile", SearchTarget.Accommodations, null, "Livno", 5, 100m, 240m);
        yield return Ran("mobile", SearchTarget.Experiences, "cheese", "Travnik", 3, null, 150m);

        yield return Ran("emir.kovac", SearchTarget.Accommodations, "chalet", "Kupres", 7, 200m, 400m);
        yield return Ran("emir.kovac", SearchTarget.Experiences, "horses", "Livno", 4, null, 120m);

        yield return Ran("sara.jukic", SearchTarget.Accommodations, "villa", "Trebinje", 8, 400m, 700m);
        yield return Ran("sara.jukic", SearchTarget.Accommodations, null, "Mostar", 5, null, 300m);
        yield return Ran("sara.jukic", SearchTarget.Experiences, null, "Trebinje", 2, null, null);

        yield return Ran("tarik.mujic", SearchTarget.Accommodations, "river", "Mostar", 3, null, 200m);
        yield return Ran("tarik.mujic", SearchTarget.Experiences, null, "Banja Luka", 5, null, 90m);

        yield return Ran("ivana.matic", SearchTarget.Accommodations, "villa", "Stolac", 6, 300m, 500m);
        yield return Ran("ivana.matic", SearchTarget.Experiences, "spa", "Fojnica", 2, null, 200m);

        yield return Ran("denis.softic", SearchTarget.Accommodations, "workspace", "Zenica", 2, null, 160m);
        yield return Ran("denis.softic", SearchTarget.Experiences, "boat", "Višegrad", 3, null, 100m);

        yield return Ran("maja.popovic", SearchTarget.Accommodations, null, "Fojnica", 2, null, 180m);
        yield return Ran("maja.popovic", SearchTarget.Experiences, "horse", "Kupres", 2, null, 140m);
    }

    private static IEnumerable<Favorite> Favorites(
        UserSeedResult users,
        ListingSeedResult listings,
        DateTime now)
    {
        var index = 0;

        Favorite Saved(string guest, string? accommodation, string? experience)
        {
            index++;

            return new Favorite
            {
                User = users.ByUsername[guest],
                Accommodation = accommodation is null
                    ? null
                    : listings.Accommodations[accommodation],
                Experience = experience is null ? null : listings.Experiences[experience],
                CreatedAt = now.AddDays(-index * 4),
            };
        }

        yield return Saved("guest", "sarajevo-loft", null);
        yield return Saved("guest", "jajce-cottage", null);
        yield return Saved("guest", "neum-stone-villa", null);
        yield return Saved("guest", null, "mostar-kravice-wine");
        yield return Saved("mobile", "neum-seafront", null);
        yield return Saved("mobile", "konjic-apartment", null);
        yield return Saved("mobile", null, "mostar-rafting");
        yield return Saved("mobile", null, "bihac-kayak");
        yield return Saved("emir.kovac", "tuzla-flat", null);
        yield return Saved("emir.kovac", null, "sarajevo-coffee-burek");
        yield return Saved("sara.jukic", "neum-stone-villa", null);
        yield return Saved("sara.jukic", null, "mostar-kravice-wine");
        yield return Saved("tarik.mujic", "neum-stone-villa", null);
        yield return Saved("ivana.matic", "sarajevo-studio", null);
        yield return Saved("ivana.matic", null, "bihac-kayak");
        yield return Saved("maja.popovic", "jajce-cottage", null);
        yield return Saved("denis.softic", "konjic-apartment", null);
        yield return Saved("denis.softic", null, "jajce-waterfall-hike");

        yield return Saved("guest", "mostar-old-bridge-house", null);
        yield return Saved("guest", null, "blagaj-dervish-house");
        yield return Saved("mobile", "livno-field-house", null);
        yield return Saved("mobile", null, "travnik-cheese-farm");
        yield return Saved("emir.kovac", "kupres-ski-chalet", null);
        yield return Saved("emir.kovac", null, "livno-wild-horses");
        yield return Saved("sara.jukic", "trebinje-vineyard-villa", null);
        yield return Saved("sara.jukic", null, "trebinje-hammam");
        yield return Saved("tarik.mujic", "mostar-riverside-apartment", null);
        yield return Saved("tarik.mujic", null, "banjaluka-nightlife");
        yield return Saved("ivana.matic", "stolac-bregava-villa", null);
        yield return Saved("ivana.matic", null, "fojnica-thermal-baths");
        yield return Saved("denis.softic", "zenica-central-flat", null);
        yield return Saved("denis.softic", null, "visegrad-drina-boat");
        yield return Saved("maja.popovic", "travnik-vlasic-cottage", null);
        yield return Saved("maja.popovic", null, "kupres-horse-ride");
    }
}
