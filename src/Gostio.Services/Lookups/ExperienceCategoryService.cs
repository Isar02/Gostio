using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class ExperienceCategoryService(GostioDbContext db)
    : LookupService<ExperienceCategory>(db, "experience category"), IExperienceCategoryService;
