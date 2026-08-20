namespace Gostio.Services.Database.Configurations;

// An enum column is a plain int in the database, so without this nothing stops
// a value the enum never defined. Built from the enum itself, so it cannot fall
// behind it: adding a member changes the constraint and EF sees a migration.
internal static class EnumCheckConstraint
{
    public static string Values<TEnum>(string columnName)
        where TEnum : struct, Enum =>
        $"[{columnName}] IN ("
        + string.Join(", ", Enum.GetValues<TEnum>().Select(value => Convert.ToInt32(value)))
        + ")";
}
