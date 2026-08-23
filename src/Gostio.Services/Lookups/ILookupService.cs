using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Lookups;

// The tables that are nothing but a name. Each one gets an interface of its
// own below this so the container can tell them apart, since the closed
// generic they all share would otherwise name six registrations at once.
public interface ILookupService
    : ICrudService<LookupResponse, LookupSearchRequest, LookupUpsertRequest, LookupUpsertRequest>;
