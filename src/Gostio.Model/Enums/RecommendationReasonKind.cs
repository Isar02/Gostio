namespace Gostio.Model.Enums;

// The first seven are the axes a taste is measured along; the rest are not.
public enum RecommendationReasonKind
{
    City = 1,
    Category = 2,
    AccommodationType = 3,
    Amenity = 4,
    Term = 5,
    Price = 6,
    Capacity = 7,
    Rating = 8,
    Popularity = 9,
    OnOffer = 10
}
