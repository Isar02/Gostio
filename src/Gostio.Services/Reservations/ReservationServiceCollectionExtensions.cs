using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Reservations;

public static class ReservationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioReservationServices(this IServiceCollection services)
    {
        services.AddGostioReservationSweep();

        services.AddScoped<ReservationAccess>();
        services.AddScoped<ReservationPlaces>();
        services.AddScoped<IReservationService, ReservationService>();
        services.AddScoped<IReservationMoveService, ReservationMoveService>();

        return services;
    }

    public static IServiceCollection AddGostioReservationSweep(this IServiceCollection services)
    {
        services.AddScoped<IReservationTransitionService, ReservationTransitionService>();
        services.AddScoped<IReservationSweep, ReservationSweep>();

        return services;
    }
}
