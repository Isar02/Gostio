using System.Reflection;
using System.Runtime.CompilerServices;
using Gostio.API.Middleware;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Tests.Architecture;

// The API reaches Entity Framework and the entities transitively through
// Gostio.Services, so the compiler allows a controller to take a DbContext or
// hand an entity straight back. Nothing but these tests stops it.
public class LayeringTests
{
    private const string EntityFrameworkNamespace = "Microsoft.EntityFrameworkCore";

    private const string EntityNamespace = "Gostio.Services.Database.Entities";

    private const string DatabaseNamespace = "Gostio.Services.Database";

    private const BindingFlags AllDeclared =
        BindingFlags.Public
        | BindingFlags.NonPublic
        | BindingFlags.Instance
        | BindingFlags.Static
        | BindingFlags.DeclaredOnly;

    private const BindingFlags PublicDeclared =
        BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;

    private static readonly Assembly Api = typeof(ExceptionHandlingMiddleware).Assembly;

    private static readonly Assembly Services = typeof(GostioDbContext).Assembly;

    [Fact]
    public void NoApiSignatureTakesAnEntityFrameworkType()
    {
        var offenders = Offenders(Api, AllDeclared, IsEntityFramework);

        Assert.True(
            offenders.Count == 0,
            "The API layer must reach the database through a service:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, offenders));
    }

    [Fact]
    public void NoApiSignatureExposesADatabaseEntity()
    {
        var offenders = Offenders(Api, AllDeclared, IsEntity);

        Assert.True(
            offenders.Count == 0,
            "The API layer must accept and return DTOs, never entities:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, offenders));
    }

    // The database namespace owns the entities and says so in its signatures.
    // Everything a caller outside it can see has to speak in DTOs, or the API
    // ends up holding an entity that no test above would catch.
    [Fact]
    public void NoServiceAboveTheDatabaseLayerExposesADatabaseEntity()
    {
        var offenders = Offenders(Services, PublicDeclared, IsEntity, OwnsTheEntities);

        Assert.True(
            offenders.Count == 0,
            "A service must return DTOs, never entities:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, offenders));
    }

    private static List<string> Offenders(
        Assembly assembly,
        BindingFlags declared,
        Func<Type, bool> forbidden,
        Func<Type, bool>? exempt = null) =>
        [.. assembly.GetTypes()
            .Where(type => !type.IsDefined(typeof(CompilerGeneratedAttribute), inherit: false))
            .Where(type => exempt is null || !exempt(type))
            .SelectMany(type => Referenced(type, declared).Select(used => (Owner: type, Used: used)))
            .Where(pair => forbidden(pair.Used))
            .Select(pair => $"  {pair.Owner.Name} refers to {pair.Used.Name}")
            .Distinct()
            .Order()];

    private static IEnumerable<Type> Referenced(Type type, BindingFlags declared)
    {
        var used = type
            .GetConstructors(declared)
            .SelectMany(constructor => constructor.GetParameters())
            .Select(parameter => parameter.ParameterType)
            .Concat(type.GetFields(declared).Select(field => field.FieldType))
            .Concat(type.GetProperties(declared).Select(property => property.PropertyType))
            .Concat(type.GetMethods(declared).SelectMany(Signature));

        return used.SelectMany(Expand);
    }

    private static IEnumerable<Type> Signature(MethodInfo method) =>
        method.GetParameters().Select(parameter => parameter.ParameterType)
            .Append(method.ReturnType);

    // A DbContext hidden inside Task<...> or DbSet<...> is still a DbContext.
    private static IEnumerable<Type> Expand(Type type)
    {
        yield return type;

        if (type.IsGenericParameter)
        {
            yield break;
        }

        var nested = type.IsGenericType
            ? type.GetGenericArguments()
            : type.HasElementType ? [type.GetElementType()!] : [];

        foreach (var argument in nested.SelectMany(Expand))
        {
            yield return argument;
        }
    }

    private static bool OwnsTheEntities(Type type) =>
        !type.IsVisible
        || (type.Namespace?.StartsWith(DatabaseNamespace, StringComparison.Ordinal) ?? false);

    private static bool IsEntity(Type type) => type.Namespace == EntityNamespace;

    private static bool IsEntityFramework(Type type) =>
        typeof(DbContext).IsAssignableFrom(type)
        || (type.Namespace?.StartsWith(EntityFrameworkNamespace, StringComparison.Ordinal) ?? false);
}
