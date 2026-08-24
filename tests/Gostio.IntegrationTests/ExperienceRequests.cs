using Gostio.Model.Requests;

namespace Gostio.IntegrationTests;

internal sealed record ExperienceReferences(int CityId, int CategoryId);

internal static class ExperienceRequests
{
    private const string Description =
        "A walk through the old town, described at the length a listing needs.";

    public static ExperienceCreateRequest New(
        ExperienceReferences references,
        string title,
        int? hostId = null,
        decimal price = 40m,
        int durationMinutes = 120) =>
        new()
        {
            HostId = hostId,
            Title = title,
            Description = Description,
            ExperienceCategoryId = references.CategoryId,
            CityId = references.CityId,
            MeetingPoint = "Sebilj",
            Latitude = 43.8593m,
            Longitude = 18.4310m,
            DurationMinutes = durationMinutes,
            PricePerPerson = price,
        };

    public static ExperienceUpdateRequest Edit(
        ExperienceReferences references,
        string title,
        bool isActive = true,
        decimal price = 40m,
        int durationMinutes = 120) =>
        new()
        {
            IsActive = isActive,
            Title = title,
            Description = Description,
            ExperienceCategoryId = references.CategoryId,
            CityId = references.CityId,
            MeetingPoint = "Sebilj",
            Latitude = 43.8593m,
            Longitude = 18.4310m,
            DurationMinutes = durationMinutes,
            PricePerPerson = price,
        };
}
