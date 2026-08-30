using Gostio.Model.Enums;
using Gostio.Model.Responses;

namespace Gostio.Services.Reports;

internal sealed class ListingReport(
    AccommodationReportSource accommodations,
    ExperienceReportSource experiences)
{
    public async Task<ListingReportResponse> BuildAsync(
        ReportRange range,
        SearchTarget target,
        ReportScope scope,
        string whenNothingSettled,
        CancellationToken cancellationToken)
    {
        var source = target == SearchTarget.Accommodations
            ? (IListingReportSource)accommodations
            : experiences;

        var chargeRows = await source.ChargesAsync(range, scope, cancellationToken);

        // Out of the very rows that carry the money, so a second currency
        // cannot settle between deciding the label and adding the figures up.
        var currency = ReportCurrency.RequireOne(
            chargeRows.Select(charge => charge.Currency), whenNothingSettled);

        var published = await source.PublishedAsync(scope, cancellationToken);
        var sold = Keyed(await source.BookingsAsync(range, scope, cancellationToken));
        var charged = Keyed(chargeRows);
        var reviews = await source.ReviewsAsync(range, scope, cancellationToken);
        var rated = Keyed(reviews);

        var rows = published
            .OrderBy(listing => listing.City, StringComparer.Ordinal)
            .ThenBy(listing => listing.Category, StringComparer.Ordinal)
            .Select(listing => Row(listing, sold, charged, rated))
            .ToList();

        return new ListingReportResponse
        {
            From = range.From,
            To = range.To,
            Target = target,
            Currency = currency,
            Rows = rows,
            Totals = Add(rows, reviews),
        };
    }

    private static ListingReportRow Row(
        ListingTally listing,
        IReadOnlyDictionary<(int, int), BookingTally> sold,
        IReadOnlyDictionary<(int, int), ChargeTally> charged,
        IReadOnlyDictionary<(int, int), ReviewTally> rated)
    {
        var place = Place(listing);

        var bookings = sold.GetValueOrDefault(place);
        var money = charged.GetValueOrDefault(place);
        var reviews = rated.GetValueOrDefault(place);

        return new ListingReportRow
        {
            CityId = listing.CityId,
            City = listing.City,
            CategoryId = listing.CategoryId,
            Category = listing.Category,
            ListingsPublished = listing.Published,
            Bookings = bookings?.Bookings ?? 0,
            UnitsSold = bookings?.UnitsSold ?? 0,
            GrossCharged = money?.GrossCharged ?? 0m,
            AverageRating = Rating(reviews?.RatingSum ?? 0, reviews?.Count ?? 0),
            ReviewCount = reviews?.Count ?? 0,
        };
    }

    // Weighed over every review rather than averaged over the rows, or a city
    // holding one rating would count for as much as one holding a hundred.
    private static ListingReportTotals Add(
        IReadOnlyList<ListingReportRow> rows,
        IReadOnlyList<ReviewTally> reviews) =>
        new()
        {
            ListingsPublished = rows.Sum(row => row.ListingsPublished),
            Bookings = rows.Sum(row => row.Bookings),
            UnitsSold = rows.Sum(row => row.UnitsSold),
            GrossCharged = rows.Sum(row => row.GrossCharged),
            AverageRating = Rating(
                reviews.Sum(review => review.RatingSum), reviews.Sum(review => review.Count)),
            ReviewCount = rows.Sum(row => row.ReviewCount),
        };

    private static decimal? Rating(int ratingSum, int count) =>
        count == 0 ? null : Math.Round((decimal)ratingSum / count, 2);

    private static Dictionary<(int, int), TTally> Keyed<TTally>(IReadOnlyList<TTally> tallies)
        where TTally : IPlacedTally =>
        tallies.ToDictionary(tally => Place(tally));

    private static (int, int) Place(IPlacedTally tally) => (tally.CityId, tally.CategoryId);
}
