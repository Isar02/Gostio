namespace Gostio.Services.Reservations;

public readonly record struct PricedRange(DateOnly StartDate, DateOnly EndDate, decimal Price);

public static class ReservationPricing
{
    // A stay covers the nights [checkIn, checkOut), and an override covers the
    // days [StartDate, EndDate] the way a host reads a calendar. Ranges never
    // overlap each other, so at most one of them prices any night.
    public static decimal TotalForNights(
        DateOnly checkIn,
        DateOnly checkOut,
        decimal basePrice,
        IReadOnlyCollection<PricedRange> overrides)
    {
        var total = 0m;

        for (var night = checkIn; night < checkOut; night = night.AddDays(1))
        {
            total += PriceOf(night, basePrice, overrides);
        }

        return total;
    }

    // Public because the calendar a guest picks on prices a night with it too.
    public static decimal PriceOf(
        DateOnly night,
        decimal basePrice,
        IReadOnlyCollection<PricedRange> overrides)
    {
        foreach (var range in overrides)
        {
            if (range.StartDate <= night && night <= range.EndDate)
            {
                return range.Price;
            }
        }

        return basePrice;
    }
}
