namespace Gostio.Services.Database.Configurations;

// An enum column is a plain int, so without this a value the enum never defined
// passes every other constraint.
internal static class EnumCheckConstraint
{
    public static string Values<TEnum>(string columnName)
        where TEnum : struct, Enum =>
        $"[{columnName}] IN ("
        + string.Join(", ", Enum.GetValues<TEnum>().Select(value => Convert.ToInt32(value)))
        + ")";
}
