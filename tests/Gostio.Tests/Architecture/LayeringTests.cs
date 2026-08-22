using System.Reflection;
using System.Runtime.CompilerServices;
using Gostio.API.Middleware;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Tests.Architecture;

// The API reaches Entity Framework and the entities transitively through
// Gostio.Services, so the compiler allows a controller to take a DbContext or
// hand an entity straight back. Nothing but these two tests stops it.
public class LayeringTests
{
    private const string EntityFrameworkNamespace = "Microsoft.EntityFrameworkCore";

    private const string EntityNamespace = "Gostio.Services.Database.Entities";

    private const BindingFlags AllDeclared =
        BindingFlags.Public
        | BindingFlags.NonPublic
        | BindingFlags.Instance
        | BindingFlags.Static
        | BindingFlags.DeclaredOnly;

    private static readonly Assembly Api = typeof(ExceptionHandlingMiddleware).Assembly;

    [Fact]
    public void NoApiSignatureTakesAnEntityFrameworkType()
    {
        var offenders = Offenders(IsEntityFramework);

        Assert.True(
            offenders.Count == 0,
            "The API layer must reach the database through a service:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, offenders));
    }

    [Fact]
    public void NoApiSignatureExposesADatabaseEntity()
    {
        var offenders = Offenders(type => type.Namespace == EntityNamespace);

        Assert.True(
            offenders.Count == 0,
            "The API layer must accept and return DTOs, never entities:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, offenders));
    }

    private static List<string> Offenders(Func<Type, bool> forbidden) =>
        [.. Api.GetTypes()
            .Where(type => !type.IsDefined(typeof(CompilerGeneratedAttribute), inherit: false))
            .SelectMany(type => Referenced(type).Select(used => (Owner: type, Used: used)))
            .Where(pair => forbidden(pair.Used))
            .Select(pair => $"  {pair.Owner.Name} refers to {pair.Used.Name}")
            .Distinct()
            .Order()];

    private static IEnumerable<Type> Referenced(Type type)
    {
        var declared = type
            .GetConstructors(AllDeclared)
            .SelectMany(constructor => constructor.GetParameters())
            .Select(parameter => parameter.ParameterType)
            .Concat(type.GetFields(AllDeclared).Select(field => field.FieldType))
            .Concat(type.GetProperties(AllDeclared).Select(property => property.PropertyType))
            .Concat(type.GetMethods(AllDeclared).SelectMany(Signature));

        return declared.SelectMany(Expand);
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

    private static bool IsEntityFramework(Type type) =>
        typeof(DbContext).IsAssignableFrom(type)
        || (type.Namespace?.StartsWith(EntityFrameworkNamespace, StringComparison.Ordinal) ?? false);
}
