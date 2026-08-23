using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class AmenityService(GostioDbContext db)
    : LookupService<Amenity>(db, "amenity"), IAmenityService;
