namespace Gostio.Services.Database.Entities;

/// <summary>
/// Reference ("lookup") tables: a short list of named rows that classifies the
/// main tables and is maintained from the administrator client. Implementing
/// this interface is what gives an entity the shared key, length and uniqueness
/// rules in <c>LookupEntityConfiguration</c>.
/// </summary>
public interface ILookupEntity
{
    int Id { get; set; }

    string Name { get; set; }
}
