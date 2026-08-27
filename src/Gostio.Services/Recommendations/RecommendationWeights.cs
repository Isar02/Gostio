using Gostio.Model.Validation;

namespace Gostio.Services.Recommendations;

public static class RecommendationWeights
{
    public const double Booking = 3.0;

    public const double Favorite = 2.0;

    public const double Search = 1.0;

    public static readonly TimeSpan HalfLife = TimeSpan.FromDays(30);

    public const double Content = 0.60;

    public const double Quality = 0.25;

    public const double Popularity = 0.15;

    public const double ColdQuality = 0.5;

    public const double ColdPopularity = 0.5;

    // How many reviews a listing needs before its own average outweighs the
    // catalogue's.
    public const int RatingPrior = 5;

    public const int MaximumReasons = 3;

    public const int ShortestTerm = 3;

    public const int RecentSearches = 50;

    public static double Of(EngagementKind kind, int? rating) => kind switch
    {
        EngagementKind.Favorite => Favorite,
        _ => Booking * RatingFactor(rating),
    };

    public static double Decay(DateTime now, DateTime at)
    {
        var age = (now - at).TotalDays;

        return age <= 0 ? 1 : Math.Pow(0.5, age / HalfLife.TotalDays);
    }

    private static double RatingFactor(int? rating) =>
        rating is int given
            ? (double)(given - ReviewRatings.Lowest)
                / (ReviewRatings.Highest - ReviewRatings.Lowest)
            : 1;
}
