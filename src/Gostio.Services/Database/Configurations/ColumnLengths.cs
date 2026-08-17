namespace Gostio.Services.Database.Configurations;

/// <summary>
/// Column lengths shared by more than one entity, so that the same concept is
/// not given two different sizes in two different configurations.
/// </summary>
internal static class ColumnLengths
{
    public const int Name = 100;

    public const int IsoCode = 2;
}
