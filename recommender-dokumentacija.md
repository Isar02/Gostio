# Recommender

Gostio suggests accommodations and experiences with **content-based filtering**
blended with a **popularity and quality prior**. A guest who has left signals is
ranked against a profile built from those signals; a guest whose signals reach
nothing in the catalogue falls back to what the rest of it thinks. Every
suggestion carries the reasons that produced its own score.

Everything below describes what the code does. The figures are the constants in
`RecommendationWeights`, and nothing in the ranking uses a number that is not
named here.

---

## The endpoint

```
GET /api/recommendations?target=Accommodations&page=1&pageSize=20
GET /api/recommendations?target=Experiences
```

Open to any signed in account; a request without a token is 401. `target` is
required and names one catalogue — a request without it, or with a value the
enumeration does not hold, is 400. The answer is the usual paged shape, ordered
best first:

```json
{
  "items": [
    {
      "listingId": 42,
      "target": "Accommodations",
      "title": "Loft in the Old Town",
      "cityName": "Sarajevo",
      "countryName": "Bosnia and Herzegovina",
      "categoryName": "City break",
      "price": 95.00,
      "coverPhotoId": 118,
      "averageRating": 4.6,
      "reviewCount": 12,
      "score": 0.8123,
      "reasons": [
        { "kind": "City", "detail": "Sarajevo" },
        { "kind": "Term", "detail": "old town" },
        { "kind": "Price", "detail": null }
      ]
    }
  ],
  "page": 1,
  "pageSize": 20,
  "totalCount": 37
}
```

`target` and `kind` travel as their names rather than their numbers, which is
what every other value of this kind in the API already answers with. `kind` is
one of `City`, `Category`, `AccommodationType`, `Amenity`, `Term`, `Price`,
`Capacity`, `Rating`, `Popularity` and `OnOffer`.

`score` is a place in one ranking rather than a measure of its own. Every
request recomputes it against the whole eligible catalogue before cutting out
the requested page. Scores in one response therefore come from the same
ranking, but scores from separate requests are not guaranteed to be comparable.

---

## The signals

Four things the application already writes are all the recommender reads. None
of them exists for its sake alone, and none is written by the recommender.

| Signal | Written when | Table |
| --- | --- | --- |
| Search | The first page of a search that names something | `SearchHistory` |
| Favourite | A guest keeps a listing | `Favorites` |
| Booking | A guest makes a reservation | `Reservations` |
| Review | A guest rates a completed booking | `Reviews` |

A search is recorded by `SearchRecorder` from the same request the filter read:
the term, the city, the guest count and the price bounds. Only a signed in
caller leaves one, only the first page does, and a term still being typed moves
the row already there rather than adding another.

A review is not a signal of its own. It scales the booking it belongs to, which
is how a guest saying a stay was poor is heard.

A reservation counts whatever became of it. A hold that lapsed and a booking
that was called off were both an attempt to book, and an attempt is interest.

---

## The taste profile

`TasteProfile.Build` turns the signals of one guest into a weight on every
**axis** their signals named. It is a pure function of the signals and reads
nothing else, which is why it can be asserted on without a database.

### Axes

An axis is a kind and a value: a city, a category, an accommodation type, an
amenity, a term. Two of them have a single axis rather than one per value —
the price and the capacity — because a listing meets those by degree rather
than by having them.

| Kind | Where a profile gets it | Where a listing gets it |
| --- | --- | --- |
| `City` | Search, engaged listing | The city it stands in |
| `Category` | Engaged listing | Accommodation category, or experience category |
| `AccommodationType` | Engaged listing | Its type |
| `Amenity` | Engaged listing | Each amenity it offers |
| `Term` | Search | Its title contains the term |
| `Price` | Search naming a bound, engaged listing | How near its price is |
| `Capacity` | Search naming a guest count | Whether it holds the party |

### Signal weight

Each signal carries a base weight, faded by how long ago it happened:

```
weight = base × 0.5 ^ (age in days / 30)
```

| Signal | Base |
| --- | --- |
| Booking | 3.0 |
| Favourite | 2.0 |
| Search | 1.0 |

A booking is scaled by what the guest said about it afterwards:

```
booking weight = 3.0 × (rating − 1) / 4
```

An unreviewed booking counts whole. Five stars leave it whole, three stars
halve it, and one star takes it away: a stay the guest disliked says nothing
about what to suggest next.

### Adding a signal to the profile

An **engaged listing** — one the guest kept or booked — contributes the axes
the listing itself sits on. A kind carries the whole of the signal's weight
however many values the listing has of it, split between them: a place with ten
amenities must not say ten times as much about a guest as the city it stands
in does. It also adds its weight to the `Price` axis, and its price to a
weighted mean that becomes the guest's preferred price.

A **search** contributes the axes it named: the city, the term, the price and
the guest count. A term is trimmed and lowered, and one shorter than three
characters is dropped — it would match almost every title, which explains
nothing. The price a search names is the middle of its range, or the single
bound it set. The 50 most recent searches of that catalogue are read.

The preferred price and the preferred party are weighted means over everything
that named one.

A profile with no axes at all reaches nothing, and so does one whose axes no
listing in the catalogue carries. Both are the cold start below.

---

## The candidates

The whole published catalogue of the target is scored on every request. A
listing is left out when

- it is not published,
- the caller hosts it,
- the caller already keeps it or has already booked it, which is no news,
- it is an experience with no active term still ahead of it, which is one
  nobody could book.

Each candidate is read as its card, its axes, its average rating, its review
count, and the number of favourites and reservations it has gathered. Engaged
listings are read through exactly the same call, so a listing means the same
thing on both sides of the comparison.

---

## The score

```
score = 0.60 × content + 0.25 × quality + 0.15 × popularity
```

Each part is in `[0, 1]` and the weights sum to one, so the score is too. It is
rounded to four decimals, and the ranking is by score descending with the
listing id breaking a tie.

### Content

The candidate is turned into a vector over the same axes as the profile. It
carries `1` on every axis it has, `1` on every profile term its title contains,
and a degree of fit on the two graded axes:

```
price fit    = p / (p + |candidate price − p|)        p = preferred price
capacity fit = 1 if room ≥ party, else room / party
```

`room` is how many the listing holds: the accommodation's `MaxGuests`, or for
an experience the largest capacity among its active terms still ahead of it.

The price fit is `1` at the asked price and `0.5` at twice it, and it falls
smoothly, so nothing is cut off by a bound nobody set.

What matched is the sum over the vector of the profile's weight on that axis
times the candidate's:

```
matched = Σ profile[axis] × candidate[axis]
```

That figure means little on its own — a guest with a wide taste matches every
listing a little — so it is read against the best the catalogue could do for
this guest:

```
content = matched / max(matched over all candidates)
```

The closest listing there is scores `1`, and the rest are measured against it.

### Quality

A listing's own average is pulled towards what the catalogue as a whole earns,
by an amount that fades as it gathers reviews of its own:

```
weighted = (n × average + 5 × prior) / (n + 5)
quality  = (weighted − 1) / 4
```

`n` is the listing's review count and `prior` is the review-weighted mean rating
over the candidate set, or `3.0` when the catalogue has no reviews at all. The
five is what stops a single five star review from topping every ranking.

### Popularity

```
popularity = ln(1 + engagements) / ln(1 + most engagements in the catalogue)
```

`engagements` is favourites plus reservations. The logarithm is what keeps one
very busy listing from flattening every other one to nothing.

### Cold start

When no candidate matched anything at all, `content` is nought for every
listing. That is a guest who has left no signals, or one whose signals named
only discrete axes nothing in this catalogue carries — a city nobody lets a
place in, a term no title holds. The two graded axes do not reach it: a price
or a party is always met to some degree by any listing that can be measured
against it, so a party of six meets a term seating one at a sixth rather than
at nothing. Leaving the weights alone would then let the two remaining terms
decide the order at a fraction of their strength, and in a proportion nobody
chose. They change instead:

```
score = 0.5 × quality + 0.5 × popularity
```

which is a plain popularity-and-quality ranking: what a first time visitor
should see. The switch is on whether anything matched rather than on whether
the profile is empty, so the two cases cannot drift apart.

---

## The explanation

Every suggestion says why it is there, and it is read off the score rather than
written beside it. The axes whose contribution to `matched` was above zero are
sorted by that contribution and the largest three become the reasons, each
naming its kind and the value it matched: the city's name, the category's name,
the amenity's name, the term the guest typed. The two graded axes name no value
of their own — a price near the one being looked at is the reason itself.

If fewer than three axes carried the listing, the reasons are filled with

- `Rating`, when the listing has reviews and its average is at or above the
  catalogue's, carrying the average as its detail,
- `Popularity`, when anybody has kept or booked it, carrying that count.

Which is also what a cold start suggestion answers with, since it has no
matched axes at all.

**Every suggestion carries at least one reason.** A listing that matched
nothing, has no reviews and has never been kept or booked would otherwise
answer with none, so the last resort is `OnOffer`, which names no value and
says exactly what happened: nothing about this guest and nothing about this
listing spoke for it, and it is here because it is part of what the catalogue
has. It is a kind of its own rather than the city the listing stands in,
because a client has to be able to tell it apart from a city that matched.

The sentence itself is left to the client, which is the side that knows what
language it speaks.

---

## Where it lives

| File | What it holds |
| --- | --- |
| `Recommendations/Feature.cs` | An axis, and an axis with a weight |
| `Recommendations/RecommendationSignals.cs` | A search and an engaged listing |
| `Recommendations/RecommendationWeights.cs` | Every figure named in this document |
| `Recommendations/TasteProfile.cs` | The profile and how it is built |
| `Recommendations/RecommendationScoring.cs` | The score and the reasons |
| `Recommendations/ListingSignals.cs` | One catalogue's queries, shared |
| `Recommendations/AccommodationSignals.cs` | The accommodation catalogue |
| `Recommendations/ExperienceSignals.cs` | The experience catalogue |
| `Recommendations/RecommendationService.cs` | Read, build, rank, page |
| `Controllers/RecommendationsController.cs` | The endpoint |

The profile and the scoring are pure functions over their inputs, so
`TasteProfileTests` and `RecommendationScoringTests` assert on them directly
with no database, and `RecommendationTests` covers what the queries answer and
what the endpoint leaves out.

---

## What it does not do

- **No stored model.** The ranking is computed from the tables on every
  request. There is nothing to train, nothing to persist and nothing that can
  go stale, and the cost is linear in the size of the catalogue. That is the
  right trade at this size; a catalogue an order of magnitude larger would want
  the candidates narrowed before they are scored.
- **No collaborative filtering.** Nothing compares one guest to another. Both
  the signals and the reasons stay inside a single account, which is also what
  makes an explanation possible.
- **No cross-catalogue taste.** A profile is built for one catalogue from the
  signals left on that catalogue. A guest who searched only for stays begins
  cold on experiences.
