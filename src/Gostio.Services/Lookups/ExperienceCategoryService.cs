using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class ExperienceCategoryService(GostioDbContext db, ILookupCache cache)
    : LookupService<ExperienceCategory>(db, "experience category", cache), IExperienceCategoryService;
