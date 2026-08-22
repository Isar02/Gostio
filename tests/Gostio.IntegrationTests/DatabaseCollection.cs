namespace Gostio.IntegrationTests;

// One database serves the whole project, so the tests that write to it share a
// collection and run one after another.
[CollectionDefinition(Name)]
public sealed class DatabaseCollection : ICollectionFixture<DatabaseFixture>
{
    public const string Name = "database";
}
