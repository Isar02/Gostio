namespace Gostio.Services.Database.Entities;

public class Role : ILookupEntity
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public ICollection<UserRole> UserRoles { get; set; } = [];
}
