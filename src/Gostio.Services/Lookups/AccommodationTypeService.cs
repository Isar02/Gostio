using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class AccommodationTypeService(GostioDbContext db, ILookupCache cache)
    : LookupService<AccommodationType>(db, "accommodation type", cache), IAccommodationTypeService;
