using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Reports;

public static class ReportServiceCollectionExtensions
{
    public static IServiceCollection AddGostioReportServices(this IServiceCollection services)
    {
        services.AddScoped<RevenueReport>();
        services.AddScoped<IReportService, ReportService>();

        return services;
    }
}
