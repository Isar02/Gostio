namespace Gostio.Model.Responses;

// The photos are absent on purpose: they are columns of bytes, and they are
// served by an endpoint of their own rather than dragged through every list.
public sealed class AccommodationResponse : IIdentified
{
    public required int Id { get; init; }

    public required int HostId { get; init; }

    public required string HostName { get; init; }

    public required string Title { get; init; }

    public required string Description { get; init; }

    public required int AccommodationTypeId { get; init; }

    public required string AccommodationTypeName { get; init; }

    public required int AccommodationCategoryId { get; init; }

    public required string AccommodationCategoryName { get; init; }

    public required int CityId { get; init; }

    public required string CityName { get; init; }

    public required string CountryName { get; init; }

    public required string Address { get; init; }

    public required decimal Latitude { get; init; }

    public required decimal Longitude { get; init; }

    public required int MaxGuests { get; init; }

    public required int Bedrooms { get; init; }

    public required int Bathrooms { get; init; }

    public required decimal PricePerNight { get; init; }

    public required decimal CleaningFee { get; init; }

    public required bool IsActive { get; init; }

    public required DateTime CreatedAt { get; init; }
}
