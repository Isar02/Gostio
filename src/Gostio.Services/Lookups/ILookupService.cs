using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Lookups;

public interface ILookupService
    : ICrudService<LookupResponse, LookupSearchRequest, LookupUpsertRequest, LookupUpsertRequest>;
