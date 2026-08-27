using System.Text.Json.Serialization;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.API.Middleware;

public static class GostioJson
{
    public static IMvcBuilder AddGostioJson(this IMvcBuilder builder) =>
        builder.AddJsonOptions(options =>
            options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
}
