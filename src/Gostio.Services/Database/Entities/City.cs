namespace Gostio.Services.Database.Entities;

public class City : IEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public int CountryId { get; set; }

    public Country Country { get; set; } = null!;
}
