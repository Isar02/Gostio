namespace Gostio.Services.Database.Entities;

public class ExperienceCategory : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;
}
