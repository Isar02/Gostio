namespace Gostio.Services.Database.Entities;

// Marks a reference table, which is what gives it the shared rules in
// LookupEntityConfiguration.
public interface ILookupEntity
{
    int Id { get; set; }

    string Name { get; set; }
}
