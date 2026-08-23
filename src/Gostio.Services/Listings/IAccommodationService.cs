using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Listings;

public interface IAccommodationService : ICrudService<
    AccommodationResponse,
    AccommodationSearchRequest,
    AccommodationCreateRequest,
    AccommodationUpdateRequest>;
