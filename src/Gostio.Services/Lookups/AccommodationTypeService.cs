using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class AccommodationTypeService(GostioDbContext db)
    : LookupService<AccommodationType>(db, "accommodation type"), IAccommodationTypeService;
