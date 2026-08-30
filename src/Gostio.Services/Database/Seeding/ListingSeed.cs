using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database.Seeding;

internal sealed record ListingSeedResult(
    IReadOnlyDictionary<string, Accommodation> Accommodations,
    IReadOnlyDictionary<string, Experience> Experiences);

internal static class ListingSeed
{
    public static async Task<ListingSeedResult> SeedAsync(
        GostioDbContext db,
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var accommodations = Accommodations(lookups, users, now)
            .ToDictionary(item => item.Slug, item => item.Listing, StringComparer.Ordinal);
        var experiences = Experiences(lookups, users, now)
            .ToDictionary(item => item.Slug, item => item.Listing, StringComparer.Ordinal);

        db.AddRange(accommodations.Values);
        db.AddRange(experiences.Values);

        await db.SaveChangesAsync(cancellationToken);

        return new ListingSeedResult(accommodations, experiences);
    }

    private static IEnumerable<(string Slug, Accommodation Listing)> Accommodations(
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now)
    {
        var index = 0;

        (string Slug, Accommodation Listing) Listing(
            string slug,
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
                Photos = [.. SeedImages.Listing(slug).Select((photo, offset) =>
                    new AccommodationPhoto
                    {
                        Image = photo.Content,
                        ContentType = photo.ContentType,
                        IsCover = offset == 0,
                        DisplayOrder = offset,
                        UploadedAt = created.AddHours(offset),
                    })],
            };

            // A row is an exception to an otherwise open calendar: a block, or a price.
            // The block is staggered per listing but wrapped short of the priced
            // weeks below, because two ranges over one night have no defined
            // winner and the endpoint that writes them refuses to overlap.
            const int firstBlockedDay = 40;
            const int blockedDays = 7;
            const int staggerDays = 3;
            const int specialPriceFromDay = 80;
            const int specialPriceThroughDay = 110;

            const int staggerPositions =
                ((specialPriceFromDay - firstBlockedDay - blockedDays) / staggerDays) + 1;

            var blockedFrom = firstBlockedDay + ((index % staggerPositions) * staggerDays);

            accommodation.Availability =
            [
                new AccommodationAvailability
                {
                    StartDate = DateOnly.FromDateTime(now.AddDays(blockedFrom)),
                    EndDate = DateOnly.FromDateTime(now.AddDays(blockedFrom + blockedDays - 1)),
                    IsAvailable = false,
                },
                new AccommodationAvailability
                {
                    StartDate = DateOnly.FromDateTime(now.AddDays(specialPriceFromDay)),
                    EndDate = DateOnly.FromDateTime(now.AddDays(specialPriceThroughDay)),
                    IsAvailable = true,
                    PriceOverride = Math.Round(pricePerNight * 1.35m, 2),
                },
            ];

            return (slug, accommodation);
        }

        yield return Listing(
            "sarajevo-loft",
            "host",
            "Old town loft with a Baščaršija view",
            "A top-floor loft two minutes from Sebilj, with beams, a reading nook and a "
            + "window that frames the copper roofs of the old bazaar.",
            "Apartment", "City break", "Sarajevo", "Kazandžiluk 12",
            43.8595m, 18.4318m, 4, 2, 1, 165m, 40m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Heating", "TV", "Workspace"]);

        yield return Listing(
            "sarajevo-studio",
            "host",
            "Compact studio by the Miljacka",
            "A quiet studio on the riverside walk, built for one or two people who plan "
            + "to spend the day outside and come back only to sleep.",
            "Studio", "City break", "Sarajevo", "Obala Kulina bana 4",
            43.8563m, 18.4131m, 2, 1, 1, 110m, 25m,
            ["Wi-Fi", "Heating", "Kitchen", "TV"]);

        yield return Listing(
            "jajce-cottage",
            "marko.perisic",
            "Cottage by the Pliva lakes",
            "A timber cottage at the waterside outside Jajce, with a wood stove, a "
            + "covered porch and a rowing boat that comes with the house.",
            "Cottage", "Mountain", "Jajce", "Jezera bb",
            44.3336m, 17.2461m, 5, 2, 1, 185m, 50m,
            ["Wi-Fi", "Free parking", "Kitchen", "Heating", "Pet friendly", "Balcony"]);

        yield return Listing(
            "neum-seafront",
            "lejla.begic",
            "Seafront apartment in Neum",
            "A first-floor apartment with the sea directly across the road, a shaded "
            + "terrace and room for a family of four.",
            "Apartment", "Seaside", "Neum", "Primorska 21",
            42.9236m, 17.6119m, 4, 2, 1, 215m, 45m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Balcony", "Free parking", "TV"]);

        yield return Listing(
            "neum-stone-villa",
            "marko.perisic",
            "Stone villa on the hill above Neum",
            "A three-storey villa in the pines above the town, with a walled garden, a "
            + "roof terrace and steps down to a bay the road does not reach.",
            "Villa", "Seaside", "Neum", "Kralja Tomislava 58",
            42.9281m, 17.5996m, 7, 4, 3, 625m, 140m,
            [
                "Wi-Fi", "Air conditioning", "Kitchen", "Free parking", "Balcony",
                "Washing machine", "TV"
            ]);

        yield return Listing(
            "konjic-apartment",
            "lejla.begic",
            "Apartment above the Neretva in Konjic",
            "A small apartment on the upper bank, with a balcony over the green water "
            + "and the old bridge two streets away.",
            "Apartment", "Countryside", "Konjic", "Varda 9",
            43.6541m, 17.9583m, 3, 1, 1, 205m, 40m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Balcony", "TV"]);

        yield return Listing(
            "tuzla-flat",
            "nikola.savic",
            "Riverside flat in Tuzla",
            "A renovated flat by the Jala, ten minutes on foot from the salt lakes and "
            + "the pedestrian centre.",
            "Apartment", "City break", "Tuzla", "Turalibegova 44",
            44.5382m, 18.6734m, 4, 2, 1, 120m, 30m,
            ["Wi-Fi", "Heating", "Kitchen", "Washing machine", "Free parking"]);

        yield return Listing(
            "mostar-old-bridge-house",
            "desktop",
            "Stone house a minute from the Old Bridge",
            "A three-storey house on the east bank with thick walls, a walled courtyard "
            + "and a first-floor terrace that looks straight down the river at the bridge.",
            "House", "Historic", "Mostar", "Jusovina 6",
            43.3369m, 17.8153m, 6, 3, 2, 240m, 55m,
            [
                "Wi-Fi", "Air conditioning", "Kitchen", "Heating", "Balcony",
                "Washing machine", "TV"
            ]);

        yield return Listing(
            "mostar-riverside-apartment",
            "lejla.begic",
            "Apartment over the Neretva",
            "A bright flat on the second floor with the river under the windows and the "
            + "walk to the old town along the bank rather than the road.",
            "Apartment", "City break", "Mostar", "Maršala Tita 88",
            43.3421m, 17.8095m, 4, 2, 1, 145m, 35m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "TV", "Workspace", "Balcony"]);

        yield return Listing(
            "trebinje-vineyard-villa",
            "desktop",
            "Villa among the Trebinje vineyards",
            "A villa outside the town with a pool, a covered kitchen under the vines and "
            + "nothing in earshot but the cicadas. The cellar it belongs to pours for guests.",
            "Villa", "Luxury", "Trebinje", "Mostaći bb",
            42.7051m, 18.3122m, 8, 4, 3, 540m, 120m,
            [
                "Wi-Fi", "Air conditioning", "Kitchen", "Swimming pool", "Free parking",
                "Balcony", "Washing machine", "TV"
            ]);

        yield return Listing(
            "banjaluka-room",
            "nikola.savic",
            "Room in a quiet street in Banja Luka",
            "One room with its own entrance, a desk under the window and the Kastel and "
            + "the riverside a short walk down the hill.",
            "Private room", "City break", "Banja Luka", "Gundulićeva 14",
            44.7689m, 17.1854m, 2, 1, 1, 65m, 15m,
            ["Wi-Fi", "Heating", "Workspace", "TV"]);

        yield return Listing(
            "blagaj-spring-house",
            "amina.hodzic",
            "Stone house at the Buna spring",
            "A restored house a few doors from where the river comes out of the cliff, "
            + "with a garden on the water and the tekke visible from the gate.",
            "House", "Countryside", "Blagaj", "Buna bb",
            43.2571m, 17.8938m, 5, 2, 2, 195m, 45m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Free parking", "Heating", "Balcony"]);

        yield return Listing(
            "pocitelj-walled-town-house",
            "marko.perisic",
            "House inside the walls of Počitelj",
            "An Ottoman house on the stepped lane below the fort, restored without "
            + "levelling anything: low doorways, deep windows and a view over the valley.",
            "House", "Historic", "Počitelj", "Počitelj bb",
            43.1322m, 17.7361m, 4, 2, 1, 170m, 40m,
            ["Wi-Fi", "Kitchen", "Heating", "Free parking", "Balcony"]);

        yield return Listing(
            "travnik-vlasic-cottage",
            "desktop",
            "Cottage under Vlašić",
            "A timber cottage on the meadow below the ski centre, with a wood stove, a "
            + "drying room for boots and the highland farms starting where the garden ends.",
            "Cottage", "Mountain", "Travnik", "Babanovac bb",
            44.3089m, 17.6472m, 6, 3, 2, 210m, 50m,
            [
                "Wi-Fi", "Heating", "Kitchen", "Free parking", "Pet friendly",
                "Washing machine", "TV"
            ]);

        yield return Listing(
            "kupres-ski-chalet",
            "nikola.savic",
            "Chalet by the Kupres slopes",
            "A chalet for a group, five minutes on foot from the lift, with a long table, "
            + "a fireplace and somewhere to leave skis that is not the hallway.",
            "Cottage", "Mountain", "Kupres", "Čajuša bb",
            43.9781m, 17.2856m, 8, 4, 2, 280m, 60m,
            [
                "Wi-Fi", "Heating", "Kitchen", "Free parking", "Washing machine",
                "TV", "Balcony"
            ]);

        yield return Listing(
            "fojnica-spa-apartment",
            "host",
            "Apartment by the Fojnica baths",
            "A plain, quiet flat two streets from the thermal complex, meant for a week "
            + "of treatments rather than for sightseeing.",
            "Apartment", "Countryside", "Fojnica", "Banjska 3",
            43.9622m, 17.9089m, 4, 2, 1, 130m, 30m,
            ["Wi-Fi", "Heating", "Kitchen", "TV", "Free parking"]);

        yield return Listing(
            "livno-field-house",
            "marko.perisic",
            "House on the Livno field",
            "A low stone house at the edge of the karst field, with the whole plain out "
            + "of the front windows and the wild horses grazing within walking distance.",
            "House", "Countryside", "Livno", "Čelebić bb",
            43.7894m, 16.9412m, 6, 3, 2, 175m, 40m,
            ["Wi-Fi", "Heating", "Kitchen", "Free parking", "Pet friendly", "Balcony"]);

        yield return Listing(
            "visegrad-drina-studio",
            "lejla.begic",
            "Studio by the Drina bridge",
            "A studio for two on the bank, with the bridge from the window and the "
            + "Andrić courtyard five minutes upstream.",
            "Studio", "Historic", "Višegrad", "Užičkog korpusa 5",
            43.7817m, 19.2889m, 2, 1, 1, 95m, 25m,
            ["Wi-Fi", "Air conditioning", "Kitchen", "Heating", "TV"]);

        yield return Listing(
            "zenica-central-flat",
            "nikola.savic",
            "Flat in the centre of Zenica",
            "A renovated flat on the pedestrian street, set up for someone working from "
            + "it during the week rather than passing through for a night.",
            "Apartment", "City break", "Zenica", "Maršala Tita 27",
            44.2019m, 17.9075m, 4, 2, 1, 105m, 25m,
            ["Wi-Fi", "Heating", "Kitchen", "Workspace", "Washing machine", "TV"]);

        yield return Listing(
            "prijedor-family-room",
            "amina.hodzic",
            "Room in a family house in Prijedor",
            "A room on the upper floor of a family house, with breakfast at the kitchen "
            + "table and Kozara half an hour up the road.",
            "Private room", "Countryside", "Prijedor", "Kozarska 41",
            44.9786m, 16.7132m, 2, 1, 1, 70m, 15m,
            ["Wi-Fi", "Heating", "Breakfast", "Free parking", "TV"]);

        yield return Listing(
            "stolac-bregava-villa",
            "host",
            "Villa above the Bregava",
            "A villa on the terraces over the river, with a garden of figs and "
            + "pomegranates and the mills of Stolac a short walk downstream.",
            "Villa", "Countryside", "Stolac", "Ada bb",
            43.0836m, 17.9548m, 7, 4, 3, 395m, 90m,
            [
                "Wi-Fi", "Air conditioning", "Kitchen", "Swimming pool", "Free parking",
                "Balcony", "Washing machine"
            ]);

        var withdrawn = Listing(
            "bihac-attic",
            "amina.hodzic",
            "Open-plan attic above the rooftops of Bihać",
            "A wide top-floor flat under the eaves, with skylights over the kitchen "
            + "island and windows onto the roofs. Withdrawn from the catalogue while "
            + "the roof above it is being replaced.",
            "Apartment", "Luxury", "Bihać", "Bosanska 19",
            44.8169m, 15.8708m, 5, 2, 2, 260m, 55m,
            ["Wi-Fi", "Heating", "Kitchen", "Air conditioning", "Workspace", "TV"]);

        withdrawn.Listing.IsActive = false;

        yield return withdrawn;
    }

    private static IEnumerable<(string Slug, Experience Listing)> Experiences(
        LookupSeedResult lookups,
        UserSeedResult users,
        DateTime now)
    {
        var index = 0;

        (string Slug, Experience Listing) Listing(
            string slug,
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

            return (slug, new Experience
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
                Photos = [.. SeedImages.Listing(slug).Select((photo, offset) =>
                    new ExperiencePhoto
                    {
                        Image = photo.Content,
                        ContentType = photo.ContentType,
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
            });
        }

        yield return Listing(
            "sarajevo-tunnel-walk",
            "host",
            "War tunnel and old town on foot",
            "Half a day across Sarajevo on foot and by tram: the tunnel museum first, "
            + "then the old bazaar, ending with coffee poured the way it is poured here.",
            "History and culture", "Sarajevo", "Tunnel of Hope museum entrance",
            43.8186m, 18.3450m, 180, 70m, 12, [-96, -40, -12, 9, 23, 44]);

        yield return Listing(
            "sarajevo-coffee-burek",
            "amina.hodzic",
            "Bosnian coffee and burek workshop",
            "Roll the dough by hand, learn why the pan is turned, then eat what you made "
            + "with coffee from a dzezva.",
            "Food and drink", "Sarajevo", "Kovači 8, blue door",
            43.8601m, 18.4360m, 150, 90m, 8, [-58, -21, 6, 19, 33]);

        yield return Listing(
            "mostar-rafting",
            "marko.perisic",
            "Rafting the Neretva canyon",
            "A full descent with two guides, a break at a spring nobody finds from the "
            + "road, and lunch at the take-out point.",
            "Adventure", "Mostar", "Boat house at Glavatičevo",
            43.5044m, 18.1417m, 300, 135m, 16, [-70, -30, 11, 26, 47]);

        yield return Listing(
            "jajce-waterfall-hike",
            "marko.perisic",
            "Pliva waterfall and mill hike",
            "An easy walk from the town gate down to the waterfall and along the little "
            + "wooden mills, with the history told on the way.",
            "Nature and outdoors", "Jajce", "Jajce old town gate",
            44.3419m, 17.2711m, 240, 60m, 14, [-63, -18, 8, 21, 39]);

        yield return Listing(
            "mostar-kravice-wine",
            "lejla.begic",
            "Kravice falls and Herzegovina wine",
            "The falls in the morning while they are still quiet, then two cellars in "
            + "Ljubuški with zilavka and blatina straight from the barrel.",
            "Food and drink", "Mostar", "Bus stop by the Old Bridge",
            43.3372m, 17.8148m, 360, 165m, 10, [-48, -15, 13, 29, 51]);

        yield return Listing(
            "trebinje-hammam",
            "desktop",
            "An afternoon in the Trebinje hammam",
            "The old bath heated for a small group: steam, a scrub on the hot stone and "
            + "tea in the cold room afterwards. Bring nothing, everything is there.",
            "Wellness", "Trebinje", "Hammam, Trebinje old town",
            42.7113m, 18.3439m, 150, 80m, 6, [-52, -24, -7, 10, 24, 41]);

        yield return Listing(
            "banjaluka-nightlife",
            "nikola.savic",
            "Banja Luka after dark",
            "Four places in one evening, from the courtyard bars off Gospodska to a "
            + "cellar that only fills after midnight, with someone who knows the order.",
            "Nightlife", "Banja Luka", "Gospodska street, by the fountain",
            44.7722m, 17.1910m, 240, 55m, 12, [-41, -16, 5, 18, 32]);

        yield return Listing(
            "blagaj-dervish-house",
            "amina.hodzic",
            "The dervish house at the spring",
            "An hour inside the tekke where the Buna comes out of the cliff, then the "
            + "walk up to the fort with the story of both told on the way.",
            "History and culture", "Blagaj", "Tekke gate, Blagaj",
            43.2564m, 17.8931m, 120, 45m, 15, [-77, -33, -11, 7, 20, 38]);

        yield return Listing(
            "travnik-cheese-farm",
            "desktop",
            "Vlašić cheese at the farm that makes it",
            "Up to the highland farm for the morning milking, the pressing and the cellar "
            + "where the wheels sit, ending with bread, cheese and cream at the long table.",
            "Food and drink", "Travnik", "Babanovac, the upper car park",
            44.3089m, 17.6472m, 270, 95m, 10, [-66, -27, -9, 12, 27, 45]);

        yield return Listing(
            "kupres-horse-ride",
            "nikola.savic",
            "Across the Kupres plateau on horseback",
            "Three hours over the open plateau at a walk and a trot, suited to riders who "
            + "have sat on a horse before but do not do it often.",
            "Nature and outdoors", "Kupres", "Stables at Zlosela",
            43.9906m, 17.2794m, 180, 85m, 8, [-44, -19, 9, 22, 36]);

        yield return Listing(
            "livno-wild-horses",
            "marko.perisic",
            "The wild horses of the Livno field",
            "Out at first light to the watering places on the karst field, where the herds "
            + "come down. Two hours of waiting and walking for the twenty minutes that matter.",
            "Nature and outdoors", "Livno", "Krug plateau, the last asphalt",
            43.8269m, 17.0078m, 240, 70m, 12, [-59, -22, 6, 16, 30, 48]);

        yield return Listing(
            "fojnica-thermal-baths",
            "host",
            "A day at the Fojnica thermal baths",
            "Full use of the thermal pools and the steam rooms with a massage booked into "
            + "the middle of it, and lunch between the two halves.",
            "Wellness", "Fojnica", "Reception, Reumal complex",
            43.9639m, 17.9061m, 300, 120m, 20, [-38, -13, 4, 15, 28, 43]);

        yield return Listing(
            "visegrad-drina-boat",
            "lejla.begic",
            "Down the Drina by boat",
            "An hour and a half on the green water below the bridge, out to where the "
            + "canyon narrows and back, with the boat stopping wherever it is worth stopping.",
            "Adventure", "Višegrad", "Landing stage under the bridge",
            43.7825m, 19.2914m, 90, 50m, 10, [-49, -20, 8, 19, 34]);

        var paused = Listing(
            "bihac-kayak",
            "lejla.begic",
            "The Una by kayak at sunrise",
            "Out before the town wakes, down the still water past the captain's tower "
            + "and back with breakfast on the bank. Paused until the spring, while the "
            + "water runs too high to launch from the promenade.",
            "Adventure", "Bihać", "Kayak landing, Una riverside promenade",
            44.8231m, 15.8629m, 210, 110m, 10, [-35, -9, 7, 17, 31]);

        paused.Listing.IsActive = false;

        yield return paused;
    }
}
