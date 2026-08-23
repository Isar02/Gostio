using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Listings;

public interface IExperienceService : ICrudService<
    ExperienceResponse,
    ExperienceSearchRequest,
    ExperienceCreateRequest,
    ExperienceUpdateRequest>;
