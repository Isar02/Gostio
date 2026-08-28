using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class AccommodationCategoryService(GostioDbContext db, ILookupCache cache)
    : LookupService<AccommodationCategory>(db, "accommodation category", cache), IAccommodationCategoryService;
