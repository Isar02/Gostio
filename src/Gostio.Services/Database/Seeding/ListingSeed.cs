using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database.Seeding;

internal sealed record ListingSeedResult(
    IReadOnlyList<Accommodation> Accommodations,
    IReadOnlyList<Experience> Experiences);

internal static class ListingSeed
{
    public static async Task<ListingSeedResult> SeedAsync(
        GostioDbContext db,
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var accommodations = Accommodations(lookups, users, now).ToList();
        var experiences = Experiences(lookups, users, now).ToList();

        db.AddRange(accommodations);
        db.AddRange(experiences);

        await db.SaveChangesAsync(cancellationToken);

        return new ListingSeedResult(accommodations, experiences);
    }

    private static IEnumerable<Accommodation> Accommodations(
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now)
    {
        var index = 0;

        Accommodation Listing(
            string host,
            string title,
            string description,
            string type,
            string category,
            string city,
            string address,
            decimal latitude,
            decimal longitude,
            int maxGuests,
            int bedrooms,
            int bathrooms,
            decimal pricePerNight,
            decimal cleaningFee,
            string[] amenities)
        {
            index++;
            var created = now.AddMonths(-12).AddDays(index * 11);

            var accommodation = new Accommodation
            {
                Host = users.ByUsername[host],
                Title = title,
                Description = description,
                AccommodationType = lookups.AccommodationTypes[type],
                AccommodationCategory = lookups.AccommodationCategories[category],
                City = lookups.Cities[city],
                Address = address,
                Latitude = latitude,
                Longitude = longitude,
                MaxGuests = maxGuests,
                Bedrooms = bedrooms,
                Bathrooms = bathrooms,
                PricePerNight = pricePerNight,
                CleaningFee = cleaningFee,
                CreatedAt = created,
                Amenities = [.. amenities.Select(name => new AccommodationAmenity
                {
                    Amenity = lookups.Amenities[name],
                })],
                Photos = [.. Enumerable.Range(0, 3).Select(offset => new AccommodationPhoto
                {
                    Image = SeedImages.Accommodation(index + offset),
                    ContentType = SeedImages.ContentType,
                    IsCover = offset == 0,
                    DisplayOrder = offset,
                    UploadedAt = created.AddHours(offset),
                })],
            };

            // A row is an exception to an otherwise open calendar: a block, or a price.
            accommodation.Availability =
            [
                new AccommodationAvailability
                {
                    StartDate = DateOnly.FromDateTime(now.AddDays((index * 3) + 40)),
                    EndDate = DateOnly.FromDateTime(now.AddDays((index * 3) + 46)),
                    IsAvailable = false,
                },
                new AccommodationAvailability
                {
                    StartDate = DateOnly.FromDateTime(now.AddDays(80)),
                    EndDate = DateOnly.FromDateTime(now.AddDays(110)),
                    IsAvailable = true,
                    PriceOverride = Math.Round(pricePerNight * 1.35m, 2),
                },
            ];

            return accommodation;
        }

        yield return Listing(
            "host",
            "Old town loft with a Baščaršija view",
            "A top-floor loft two minutes from Sebilj, with beams, a reading nook and a "
            + "window that frames the copper roofs of the old bazaar.",
            "Apartment", "City break", "Sarajevo", "Kazandžiluk 12",
            43.8595m, 18.4318m, 4, 2, 1, 165m, 40m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Heating", "TV", "Workspace"]);

        yield return Listing(
            "amina.hodzic",
            "Stone house above the Neretva",
            "A restored stone house on the left bank, five minutes uphill from the Old "
            + "Bridge. Thick walls keep it cool through August.",
            "House", "Historic", "Mostar", "Maršala Tita 88",
            43.3391m, 17.8156m, 6, 3, 2, 235m, 60m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Free parking", "Balcony", "Washing machine"]);

        yield return Listing(
            "host",
            "Compact studio by the Miljacka",
            "A quiet studio on the riverside walk, built for one or two people who plan "
            + "to spend the day outside and come back only to sleep.",
            "Studio", "City break", "Sarajevo", "Obala Kulina bana 4",
            43.8563m, 18.4131m, 2, 1, 1, 110m, 25m,
            ["Wi-Fi", "Heating", "Kitchen", "TV"]);

        yield return Listing(
            "marko.perisic",
            "Cottage by the Pliva lakes",
            "A timber cottage at the waterside outside Jajce, with a wood stove, a "
            + "covered porch and a rowing boat that comes with the house.",
            "Cottage", "Mountain", "Jajce", "Jezera bb",
            44.3336m, 17.2461m, 5, 2, 1, 185m, 50m,
            ["Wi-Fi", "Free parking", "Kitchen", "Heating", "Pet friendly", "Balcony"]);

        yield return Listing(
            "lejla.begic",
            "Seafront apartment in Neum",
            "A first-floor apartment with the sea directly across the road, a shaded "
            + "terrace and room for a family of four.",
            "Apartment", "Seaside", "Neum", "Primorska 21",
            42.9236m, 17.6119m, 4, 2, 1, 215m, 45m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Balcony", "Free parking", "TV"]);

        yield return Listing(
            "nikola.savic",
            "Villa with a pool above Trebinje",
            "A hillside villa in the vineyards, with a heated pool, an outdoor kitchen "
            + "and the whole valley below the terrace.",
            "Villa", "Luxury", "Trebinje", "Gornje Police 7",
            42.7189m, 18.3494m, 8, 4, 3, 510m, 120m,
            [
                "Wi-Fi", "Air conditioning", "Kitchen", "Swimming pool", "Free parking",
                "Washing machine", "Balcony", "TV"
            ]);

        yield return Listing(
            "amina.hodzic",
            "Quiet room in the centre of Banja Luka",
            "A private room in a shared flat one block from Gospodska, suited to a "
            + "single traveller who wants a bed and a desk.",
            "Private room", "City break", "Banja Luka", "Veselina Masleše 30",
            44.7722m, 17.1910m, 2, 1, 1, 80m, 20m,
            ["Wi-Fi", "Heating", "Workspace", "TV"]);

        yield return Listing(
            "marko.perisic",
            "Stone villa on the hill above Neum",
            "A three-storey villa in the pines above the town, with a walled garden, a "
            + "roof terrace and steps down to a bay the road does not reach.",
            "Villa", "Seaside", "Neum", "Kralja Tomislava 58",
            42.9281m, 17.5996m, 7, 4, 3, 625m, 140m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Balcony", "Washing machine", "TV"]);

        yield return Listing(
            "lejla.begic",
            "Apartment above the Neretva in Konjic",
            "A small apartment on the upper bank, with a balcony over the green water "
            + "and the old bridge two streets away.",
            "Apartment", "Countryside", "Konjic", "Varda 9",
            43.6541m, 17.9583m, 3, 1, 1, 205m, 40m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Balcony", "TV"]);

        yield return Listing(
            "nikola.savic",
            "Riverside flat in Tuzla",
            "A renovated flat by the Jala, ten minutes on foot from the salt lakes and "
            + "the pedestrian centre.",
            "Apartment", "City break", "Tuzla", "Turalibegova 44",
            44.5382m, 18.6734m, 4, 2, 1, 120m, 30m,
            ["Wi-Fi", "Heating", "Kitchen", "Washing machine", "Free parking"]);

        var withdrawn = Listing(
            "amina.hodzic",
            "Attic studio in Bihać",
            "An attic studio by the Una, withdrawn from the catalogue while the roof is "
            + "being replaced.",
            "Studio", "Countryside", "Bihać", "Bosanska 19",
            44.8169m, 15.8708m, 2, 1, 1, 100m, 20m,
            ["Wi-Fi", "Heating", "Kitchen"]);

        withdrawn.IsActive = false;

        yield return withdrawn;
    }

    private static IEnumerable<Experience> Experiences(
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now)
    {
        var index = 0;

        Experience Listing(
            string host,
            string title,
            string description,
            string category,
            string city,
            string meetingPoint,
            decimal latitude,
            decimal longitude,
            int durationMinutes,
            decimal pricePerPerson,
            int capacity,
            int[] slotDayOffsets)
        {
            index++;
            var created = now.AddMonths(-10).AddDays(index * 13);

            return new Experience
            {
                Host = users.ByUsername[host],
                Title = title,
                Description = description,
                ExperienceCategory = lookups.ExperienceCategories[category],
                City = lookups.Cities[city],
                MeetingPoint = meetingPoint,
                Latitude = latitude,
                Longitude = longitude,
                DurationMinutes = durationMinutes,
                PricePerPerson = pricePerPerson,
                CreatedAt = created,
                Photos = [.. Enumerable.Range(0, 2).Select(offset => new ExperiencePhoto
                {
                    Image = SeedImages.Experience(index + offset),
                    ContentType = SeedImages.ContentType,
                    IsCover = offset == 0,
                    DisplayOrder = offset,
                    UploadedAt = created.AddHours(offset),
                })],
                Slots = [.. slotDayOffsets.Select(offset => new ExperienceSlot
                {
                    StartTime = now.Date.AddDays(offset).AddHours(9 + (Math.Abs(offset) % 8)),
                    DurationMinutes = durationMinutes,
                    Capacity = capacity,
                    CreatedAt = created,
                })],
            };
        }

        yield return Listing(
            "host",
            "War tunnel and old town on foot",
            "Half a day across Sarajevo on foot and by tram: the tunnel museum first, "
            + "then the old bazaar, ending with coffee poured the way it is poured here.",
            "History and culture", "Sarajevo", "Tunnel of Hope museum entrance",
            43.8186m, 18.3450m, 180, 70m, 12, [-96, -40, -12, 9, 23, 44]);

        yield return Listing(
            "amina.hodzic",
            "Bosnian coffee and burek workshop",
            "Roll the dough by hand, learn why the pan is turned, then eat what you made "
            + "with coffee from a dzezva.",
            "Food and drink", "Sarajevo", "Kovači 8, blue door",
            43.8601m, 18.4360m, 150, 90m, 8, [-58, -21, 6, 19, 33]);

        yield return Listing(
            "marko.perisic",
            "Rafting the Neretva canyon",
            "A full descent with two guides, a break at a spring nobody finds from the "
            + "road, and lunch at the take-out point.",
            "Adventure", "Mostar", "Boat house at Glavatičevo",
            43.5044m, 18.1417m, 300, 135m, 16, [-70, -30, 11, 26, 47]);

        yield return Listing(
            "marko.perisic",
            "Pliva waterfall and mill hike",
            "An easy walk from the town gate down to the waterfall and along the little "
            + "wooden mills, with the history told on the way.",
            "Nature and outdoors", "Jajce", "Jajce old town gate",
            44.3419m, 17.2711m, 240, 60m, 14, [-63, -18, 8, 21, 39]);

        yield return Listing(
            "lejla.begic",
            "Kravice falls and Herzegovina wine",
            "The falls in the morning while they are still quiet, then two cellars in "
            + "Ljubuški with zilavka and blatina straight from the barrel.",
            "Food and drink", "Mostar", "Bus stop by the Old Bridge",
            43.3372m, 17.8148m, 360, 165m, 10, [-48, -15, 13, 29, 51]);

        yield return Listing(
            "lejla.begic",
            "The Una by kayak at sunrise",
            "Out before the town wakes, down the still water past the captain's tower "
            + "and back with breakfast on the bank.",
            "Adventure", "Bihać", "Kayak landing, Una riverside promenade",
            44.8231m, 15.8629m, 210, 110m, 10, [-35, -9, 7, 17, 31]);

        yield return Listing(
            "nikola.savic",
            "Hammam and spa afternoon in Trebinje",
            "An unhurried afternoon in a restored hammam, with a massage and mint tea in "
            + "the courtyard afterwards.",
            "Wellness", "Trebinje", "Hammam, Trebinje old town",
            42.7112m, 18.3437m, 120, 120m, 6, [-27, -5, 10, 24, 41]);

        var paused = Listing(
            "nikola.savic",
            "Banja Luka after dark",
            "A night walk between three bars and the riverside, paused for the season "
            + "while the guide is away.",
            "Nightlife", "Banja Luka", "Krajina square, by the clock",
            44.7686m, 17.1919m, 120, 50m, 12, [-40, -12]);

        paused.IsActive = false;

        yield return paused;
    }
}
