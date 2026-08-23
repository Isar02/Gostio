using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class AccommodationCategoryService(GostioDbContext db)
    : LookupService<AccommodationCategory>(db, "accommodation category"), IAccommodationCategoryService;
