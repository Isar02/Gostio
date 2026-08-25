namespace Gostio.Model.Validation;

// The bounds the check constraint states in SQL. Both sides read them here, so
// a star the database refuses cannot be a star a form offers.
public static class ReviewRatings
{
    public const int Lowest = 1;

    public const int Highest = 5;
}
