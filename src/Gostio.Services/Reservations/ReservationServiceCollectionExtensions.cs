using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Gostio.Services.Reservations;

public static class ReservationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioReservationServices(this IServiceCollection services)
    {
        services.AddGostioReservationSweep();

        services.TryAddSingleton(TimeProvider.System);

        services.AddScoped<ReservationAccess>();
        services.AddScoped<ReservationPlaces>();
        services.AddScoped<IReservationService, ReservationService>();
        services.AddScoped<IReservationMoveService, ReservationMoveService>();

        return services;
    }

    public static IServiceCollection AddGostioReservationSweep(this IServiceCollection services)
    {
        services.AddScoped<IReservationTransitionService, ReservationTransitionService>();
        services.AddScoped<IReservationNotices, ReservationNotices>();
        services.AddScoped<IReservationSweep, ReservationSweep>();

        return services;
    }
}
