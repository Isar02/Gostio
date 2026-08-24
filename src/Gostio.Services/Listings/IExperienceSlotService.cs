using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IExperienceSlotService
{
    Task<PagedResult<ExperienceSlotResponse>> SearchAsync(
        int experienceId,
        ExperienceSlotSearchRequest search,
        CancellationToken cancellationToken);

    Task<ExperienceSlotResponse> GetAsync(
        int experienceId,
        int slotId,
        CancellationToken cancellationToken);

    Task<ExperienceSlotResponse> AddAsync(
        int experienceId,
        ExperienceSlotCreateRequest request,
        CancellationToken cancellationToken);

    Task<ExperienceSlotResponse> UpdateAsync(
        int experienceId,
        int slotId,
        ExperienceSlotUpdateRequest request,
        CancellationToken cancellationToken);

    Task DeleteAsync(int experienceId, int slotId, CancellationToken cancellationToken);
}
